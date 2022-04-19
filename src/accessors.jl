"""
    get_datetimes(system)

Extract datetimes from a `System`.
"""
function get_datetimes(system::System)
    return axiskeys(system.offer_curve, 2)
end

"""
    gens_per_zone(gens::Generators)

Returns a `Dict` with  keys of `Zone` numbers and values of generator names in that zone.
"""
function gens_per_zone(gens::Generators)
    gens_per_zone = Dict{Int, Vector{Int}}()
    for (name, zone) in zip(gens.name, gens.zone)
        if haskey(gens_per_zone, zone)
            push!(gens_per_zone[zone], name)
        else
            gens_per_zone[zone] = [name]
        end
    end
    return gens_per_zone
end

"""
    branches_by_breakpoints(branches::Branches)

Returns three vectors containing of the names of branches which have 0, 1, and 2 breakpoints.
"""
function branches_by_breakpoints(branches::Branches)
    zero_bp, one_bp, two_bp = String[], String[], String[]
    for (name, breaks, mon) in zip(branches.name, branches.break_points, branches.is_monitored)
        if mon
            if length(breaks) == 0
                push!(zero_bp, name)
            elseif length(breaks) == 1
                push!(one_bp, name)
            else
                push!(two_bp, name)
            end
        end
    end
    return zero_bp, one_bp, two_bp
end

function get_regulation_ts(system::System)
    return get_ancillary_ts(system, :reg)
end

function get_spinning_ts(system::System)
    return get_ancillary_ts(system, :spin)
end

function get_on_sup_ts(system::System)
    return get_ancillary_ts(system, :sup_on)
end

function get_off_sup_ts(system::System)
    return get_ancillary_ts(system, :sup_off)
end

"""
    get_ancillary_ts(system, service)

Returns a `KeyedArray` with all the generators and their contribution to the specified
`service`.  If a generator does not contribute to the `service` it will appear with a `0.0`.
"""
function get_ancillary_ts(system::System, service::Symbol)
    all_gens = system.generators.name
    all_gens_array = KeyedArray(zeros(length(all_gens), 24); ids=all_gens, datetimes=get_datetimes(system))
    for g in axiskeys(getproperty(system.ancillary_services, service), 1)
        all_gens_array(g, :) .+= getproperty(system.ancillary_services, service)(g, :)
    end
    return all_gens_array
end
