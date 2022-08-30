"""
    compute_ptdf(system::System; block_size, reference_bus_index) -> KeyedArray
    compute_ptdf(buses::Buses, branches::Branches; block_size, reference_bus_index) -> KeyedArray

Takes a system, or data for that system, representing a `M` branch, `N` bus grid
and returns the `M * N` DC-Power Transfer Distribution Factor (DC-PTDF) matrix of the network.

For a ~15,000 bus system with aggregated borders, this is expected to take ~1 minute.

# Keywords
- `block_size=13_000`: Block size to be used when partitioning a big matrix for inversion.
- `reference_bus=first(keys(buses))`: The name of the reference bus.

# Output
- `::KeyedArray`: The PTDF matrix; the axes contain the branch and bus names.

!!! note
    The input data must have no isolated components or islands.
"""
function compute_ptdf(system::System; kwargs...)
    return compute_ptdf(get_buses(system), get_branches(system); kwargs...)
end

function compute_ptdf(
    buses::Buses,
    branches::Branches;
    block_size=13_000,
    reference_bus=nothing,
)
    bus_names = collect(keys(buses))
    reference_bus_index = _reference_bus(reference_bus, bus_names)

    incid_matrix = _incidence(buses, branches)
    n_branches, n_buses = size(incid_matrix)

    # Remove column related to reference bus from incidence matrix
    incid_matrix = incid_matrix[:, Not(reference_bus_index)]

    B_fl_tilde = sparse(diagm(_series_susceptance(branches))) * incid_matrix
    B_bus_tilde_inv = big_mat_inv(
        Matrix(incid_matrix' * B_fl_tilde),
        block_size=block_size
    )
    ptdf_matrix = B_fl_tilde * B_bus_tilde_inv

    # Add reference bus column back, filled with zeros
    @views ptdf_matrix = hcat(
        ptdf_matrix[:, 1:(reference_bus_index - 1)],
        zeros(n_branches),
        ptdf_matrix[:, reference_bus_index:end],
    )

    return KeyedArray(ptdf_matrix, (collect(keys(branches)), bus_names))
end

function _reference_bus(reference_bus, bus_names)
    reference_bus === nothing && return 1

    idx = findfirst(==(reference_bus), bus_names)
    idx === nothing && throw(ArgumentError("Reference bus '$reference_bus' not found."))
    return idx
end

"""
    _series_susceptance(branches) -> Vector{Float64}

Calculates the susceptance of the elements in the branch Dictionary The calculation is
different depending if the element is a line (no tap) or transformer (tap present).
"""
function _series_susceptance(branches)
    susceptance = map(_branch_susceptance, branches)
    return collect(susceptance)
end

function _branch_susceptance(b)::Float64
    if b.tap === missing
        return -1 / b.reactance
    end

    return imag(1 / ((b.resistance + b.reactance * 1im) * (b.tap * exp(b.angle * 1im))))
end

"""
    _incidence(buses, branches) -> SparseMatrix

Returns the sparse edge-node incidence matrix related to the buses and branches used as
inputs. Matrix axes correspond to `(keys(branches), keys(buses))`
"""
function _incidence(buses, branches)
    n_buses = length(buses)
    n_branches = length(branches)

    # Define the mapping of buses/branches to the incidence/PTDF matrix
    bus_lookup = _make_ax_ref(buses)

    # Compute incidence matrix
    A_to = sparse(
        1:n_branches,
        [bus_lookup[b.to_bus] for b in branches],
        fill(-1, n_branches),
        n_branches,
        n_buses
    )
    A_from = sparse(
        1:n_branches,
        [bus_lookup[b.from_bus] for b in branches],
        fill(1, n_branches),
        n_branches,
        n_buses
    )
    incid_matrix = A_to + A_from

    return incid_matrix
end

function _make_ax_ref(ax::Dictionary)
    return Dictionary(keys(ax), 1:length(ax))
end

"""
    compute_lodf(system, branch_names_out) -> KeyedArray
    compute_lodf(system::System, ptdf_matrix, branch_names_out) -> KeyedArray
    compute_lodf(buses, branches, ptdf, branch_names_out) -> KeyedArray

Returns the `M*O` DC-Line Outage Distribution Factor (DC-LODF) matrix of the network.

**Important Note:** In the current implementation, we use `lodf` only if the contingency
scenario does not have any line coming in service. We can also use this function if we want
to ignore the lines coming in service.

# Inputs
- `buses::Buses`
- `branches::Branches`
- `ptdf_matrix`: The pre-calculated PTDF matrix of the system
- `branch_names_out`: The names of the branches that are going out in the contingency scenario.

# Output
- The LODF matrix as a `KeyedArray`. The axes are the branch names and `branch_names_out`.

!!! note
    The resulting LODF matrix is sensitive to the input PTDF matrix. Using a thresholded
    PTDF as input might lead to imprecisions in constrast to using the full PTDF.
"""
function compute_lodf(system::System, branch_names_out)
    ptdf_matrix = get_ptdf(system)
    ismissing(ptdf_matrix) && throw(ArgumentError("System PTDF is missing."))

    return compute_lodf(system, ptdf_matrix, branch_names_out)
end

function compute_lodf(system::System, ptdf_matrix, branch_names_out)
    buses = get_buses(system)
    branches = get_branches(system)

    return compute_lodf(buses, branches, ptdf_matrix, branch_names_out)
end

function compute_lodf(buses::Buses, branches::Branches, ptdf_matrix, branch_names_out)
    branch_out_names = collect(filter(in(branch_names_out), keys(branches)))
    branches_out = getindices(branches, branch_out_names)

    if length(branch_out_names) < length(unique(branch_names_out))
        @debug("Some of the lines to go out were not found in the line data.")
    end

    if isempty(branches_out)
        @debug(
            "All the lines to go out are already out of service.
            You can ignore this contingency."
        )
        return KeyedArray(Matrix{Float64}(undef, 0, 0), (String[], Int[]))
    end

    incid_out = _incidence(buses, branches_out)

    branch_names = collect(keys(branches))
    branch_lookup = _make_ax_ref(branches)

    # Our monitored lines are all the lines
    ptdf_mo = ptdf_matrix.data * incid_out'
    # Indices of the branches going out
    ind_br_out = [branch_lookup[b] for b in branch_out_names]
    ptdf_oo = ptdf_mo[ind_br_out, :]
    lodf_matrix = ptdf_mo * inv(I - ptdf_oo)
    # Discard any name that wasn't matched, and ensure the order is in line with the PSSE
    lodf_matrix = KeyedArray(lodf_matrix, (branch_names, branch_out_names))

    # If a monitored line is going out, manually correct LODF values so that the
    # post-contingency flow is zero
    for br in branch_out_names
        if br in branch_names
            _correct_lodf!(lodf_matrix, br)
        end
    end

    return lodf_matrix
end

"""
    _correct_lodf!(lodf_matrix::KeyedArray, br)

Sets the LODF row corresponding to branch `br` to zero, except for the element `(br, br)`,
which is set to -1. This is to ensure the post-contingency flow on a line that is going out
and is also monitored is set to zero.
"""
function _correct_lodf!(lodf_matrix::KeyedArray, br)
    lodf_matrix(br, :) .= zeros(size(lodf_matrix(br, :)))
    lodf_matrix[Key(br), Key(br)] = -1.0

    return lodf_matrix
end
