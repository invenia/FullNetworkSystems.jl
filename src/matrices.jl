"""
    ptdf(system::System; block_size, reference_bus_index) -> KeyedArray
    ptdf(buses::DataFrame, branches::DataFrame; block_size, reference_bus_index) -> KeyedArray

Takes a system, or tabular data for that system, representing a `M` branch, `N` bus grid
and returns the `M * N` DC-Power Transfer Distribution Factor (DC-PTDF) matrix of the network.

For a ~15,000 bus system with aggregated borders, this is expected to take ~1 minute.

# Keywords
- `block_size=13_000`: Block size to be used when partitioning a big matrix for inversion.
- `reference_bus_index=1`: The index of the reference bus.

# Output
- `::KeyedArray`: The PTDF matrix; the axes contain the branch names and bus numbers.

!!! note
    The input data must have no isolated components or islands.
"""
function ptdf(system::System; block_size=13_000, reference_bus_index=1)
    buses = DataFrame(get_buses(system))
    branches = DataFrame(get_branches(system))
    
    return ptdf(buses, branches; block_size)
end

function ptdf(buses::DataFrame, branches::DataFrame; block_size=13_000, reference_bus_index=1)
    incid_matrix = _incidence(buses, branches)
    n_branches, n_buses = size(incid_matrix)

    # Remove column related to reference bus from incidence matrix
    incid_matrix = incid_matrix[:, setdiff(1:n_buses, reference_bus_index)]

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

    return KeyedArray(ptdf_matrix, (branches.name, buses.name))
end

"""
    _series_susceptance(branch_df) -> Vector{Float64}

Calculates the susceptance of the elements in the branch DataFrame. The calculation is
different depending if the element is a line (no tap) or transformer (tap present).
"""
function _series_susceptance(branch_df)
    n = size(branch_df, 1)
    susceptance = Vector{Float64}(undef, n)
    for i in 1:n
        if branch_df.tap[i] === missing
            susceptance[i] = -1 / branch_df.reactance[i]
        else
            susceptance[i] = imag(
                1 / (
                    (branch_df.resistance[i] + branch_df.reactance[i] * 1im) *
                    (branch_df.tap[i] * exp(branch_df.angle[i] * 1im))
                )
            )
        end
    end
    return susceptance
end

"""
    _incidence(buses, branches) -> SparseMatrix

Returns the sparse edge-node incidence matrix related to the buses and branches used as
inputs. Matrix axes correspond to `(branches.name, buses.name)`
"""
function _incidence(buses, branches)
    n_buses = size(buses, 1)
    n_branches = size(branches, 1)

    # Define the mapping of buses/branches to the incidence/PTDF matrix
    bus_lookup = _make_ax_ref(buses.name)

    # Compute incidence matrix
    A_to = sparse(
        1:n_branches,
        [bus_lookup[b] for b in branches.to_bus],
        fill(-1, n_branches),
        n_branches,
        n_buses
    )
    A_from = sparse(
        1:n_branches,
        [bus_lookup[b] for b in branches.from_bus],
        fill(1, n_branches),
        n_branches,
        n_buses
    )
    incid_matrix = A_to + A_from

    return incid_matrix
end

function _make_ax_ref(ax::AbstractVector)
    ref = Dict{eltype(ax), Int}()
    for (ix, el) in enumerate(ax)
        if haskey(ref, el)
            @error("Repeated index element $el. Index sets must have unique elements.")
        end
        ref[el] = ix
    end
    return ref
end

"""
    lodf(system, branch_names_out) -> KeyedArray
    lodf(buses, branches, ptdf, branch_names_out) -> KeyedArray

Returns the `M*O` DC-Line Outage Distribution Factor (DC-LODF) matrix of the network.

**Important Note:** In the current implementation, we use `lodf` only if the contingency
scenario does not have any line coming in service. We can also use this function if we want
to ignore the lines coming in service.

# Inputs
- `buses::DataFrame`
- `branches::DataFrame`
- `ptdf_matrix`: The pre-calculated PTDF matrix of the system
- `branch_names_out`: The names of the branches that are going out in the contingency scenario.

# Output
- The LODF matrix as a `KeyedArray`. The axes are the branch names and `branch_names_out`.

!!! note
    The resulting LODF matrix is sensitive to the input PTDF matrix. Using a thresholded
    PTDF as input might lead to imprecisions in constrast to using the full PTDF.
"""
function lodf(system::System, branch_names_out)
    buses = DataFrame(get_buses(system))
    branches = DataFrame(get_branches(system))
    ptdf_mat = get_ptdf(system)

    ismissing(ptdf_mat) && throw(ArgumentError("System PTDF is missing."))

    return lodf(buses, branches, ptdf_mat, branch_names_out)
end

function lodf(buses::DataFrame, branches::DataFrame, ptdf_matrix, branch_names_out)
    branches_out = filter(:name => in(branch_names_out), branches)

    if length(unique(branches_out.name)) < length(unique(branch_names_out))
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

    branch_names = branches.name
    branch_out_names = branches_out.name
    branch_lookup = _make_ax_ref(branch_names)

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
