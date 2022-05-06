"""
    get_datetimes(system)

Extract datetimes from a `System`.
"""
function get_datetimes(system::System)
    # use offer_curve axiskeys because all subtypes of System have offer_curve
    return axiskeys(system.generator_time_series.offer_curve, 2)
end

get_zones(system::System) = system.zones

"Returns a `Dictionary` with zonal regulation requirements indexed by zone number."
function get_regulation_requirements(system::System)
    return map(system.zones) do zone
        zone.reg
    end
end

"Returns a `Dictionary` with zonal operating reserve requirements indexed by zone number."
function get_operating_reserve_requirements(system::System)
    return map(system.zones) do zone
        sum([zone.reg, zone.spin, zone.sup_on, zone.sup_off])
    end
end

"Extract the static component attributes for buses, generators and branches from a `System`."
function get_static_components(system::System)
    return system.buses, system.generators, system.branches
end

"Returns a `Dictionary` of `Bus` objects in the `System` indexed by bus name."
get_buses(system::System) = system.buses
"Returns a `Dictionary` of `Generator` objects in the `System` indexed by unit code."
get_generators(system::System) = system.generators
"Returns a `Dictionary` of `Branch` objects in the `System` indexed by branch name."
get_branches(system::System) = system.branches

"Returns a `Dictionary` of unit codes at each bus."
get_gens_per_bus(system::System) = system.gens_per_bus
"Returns a `Dictionary` of load names at each bus."
get_loads_per_bus(system::System) = system.loads_per_bus

"Returns the power transfer distribution factor of the system."
get_ptdf(system::System) = system.PTDF
"Returns the line outage distribution factor matrix of the system for a set of contingencies."
get_lodf(system::System) = system.LODF

"Returns the generation of the generator at the start of the time period (MW)"
get_initial_generation(system::System) = system.generator_time_series.initial_generation
"Returns time series data of the load in the system"
get_load(system::System) = system.loads
"Returns time series data of the generator offer curves"
get_offer_curve(system::System) = system.generator_time_series.offer_curve
"Returns time series data of minimum generator output (MW)"
get_pmin(system::System) = system.generator_time_series.pmin
"Returns time series data of maximum generator output (MW)"
get_pmax(system::System) = system.generator_time_series.pmax
"Returns time series data of minimum generator output in the ancillary services market (MW)"
get_regmin(system::System) = system.generator_time_series.regulation_min
"Returns time series data of maximum generator output in the ancillary services market (MW)"
get_regmax(system::System) = system.generator_time_series.regulation_max

"Returns time series data of offer prices for ancillary servives regulation (\$ /MW)"
get_regulation(system::System) = system.generator_time_series.asm_regulation
"Returns time series data of offer prices for ancillary servives spinning (\$ /MW)"
get_spinning(system::System) = system.generator_time_series.asm_spin
"Returns time series data of offer prices for ancillary servives supplemental on (\$ /MW)"
get_supplemental_on(system::System) = system.generator_time_series.asm_sup_on
"Returns time series data of offer prices for ancillary servives supplemental off (\$ /MW)"
get_supplemental_off(system::System) = system.generator_time_series.asm_sup_off

"""
Returns a collection of the units that submitted regulation offers in the ancillary services
market.
"""
function get_regulation_providers(system::System)
    ts = system.generator_time_series.asm_regulation
    return _get_providers(ts)
end

"""
Returns a collection of the units that submitted spinning offers in the ancillary services
market.
"""
function get_spinning_providers(system::System)
    ts = system.generator_time_series.asm_spin
    return _get_providers(ts)
end

"""
Returns a collection of the units that submitted supplemental on offers in the ancillary
services market.
"""
function get_sup_on_providers(system::System)
    ts = system.generator_time_series.asm_sup_on
    return _get_providers(ts)
end

"""
Returns a collection of the units that submitted supplemental off offers in the ancillary
services market.
"""
function get_sup_off_providers(system::System)
    ts = system.generator_time_series.asm_sup_off
    return _get_providers(ts)
end

function _get_providers(ts)
    units = axiskeys(ts, 1)
    providers = vec(sum(ts .!= 0.0, dims=2) .!= 0)
    return units[providers]
end

"Returns a flag indicating whether each generator was on at the start of the day."
function get_initial_commitment(system::SystemDA)
    return map(system.generator_time_series.initial_generation) do i
        i == 0.0 ? false : true
    end
end

"Returns a `Dictionary` of increment bids at each bus."
get_incs_per_bus(system::SystemDA) = system.incs_per_bus
"Returns a `Dictionary` of decrement bids at each bus."
get_decs_per_bus(system::SystemDA) = system.decs_per_bus
"Returns a `Dictionary` of price sensitive demand bids at each bus."
get_psds_per_bus(system::SystemDA) = system.psds_per_bus

"""
Returns time series data of bids for the bid type indicated.  Bid type must be one of
`:increment`, `:decrement` or `:price_sensitive_demand`.
"""
function get_bids(system::SystemDA, type_of_bid::Symbol)
    return getproperty(system, type_of_bid)
end

"Returns time series data of flags indicating if the generator is available to be committed in each hour"
get_availability(system::SystemDA) = system.generator_status.availability
"Returns time series data of flags indicating if the generator must be committed in each hour"
get_must_run(system::SystemDA) = system.generator_status.must_run

"Returns time series data of generator status in each hour"
get_commitment_status(system::SystemRT) = system.generator_status.status
"Returns time series data of generator regulation status in each hour"
get_commitment_reg_status(system::SystemRT) = system.generator_status.status_regulation

"""
    gens_per_zone(system::System)

Returns a `Dict` with  keys of `Zone` numbers and values of generator names in that zone.
"""
function gens_per_zone(system::System)
    gens_per_zone = Dict{Int, Vector{Int}}()
    for gen in system.generators
        if haskey(gens_per_zone, gen.zone)
            push!(gens_per_zone[gen.zone], gen.unit_code)
        else
            gens_per_zone[gen.zone] = [gen.unit_code]
        end
    end
    gens_per_zone[MARKET_WIDE_ZONE] = collect(keys(system.generators))
    return gens_per_zone
end

"""
    branches_by_breakpoints(system::System)

Returns three vectors containing of the names of branches which have 0, 1, and 2 breakpoints.
"""
function branches_by_breakpoints(system::System)
    zero_bp, one_bp, two_bp = String[], String[], String[]
    for branch in system.branches
        if branch.is_monitored
            if all(branch.break_points .== 0.0)
                push!(zero_bp, branch.name)
            elseif last(branch.break_points) == 0.0
                push!(one_bp, branch.name)
            else
                push!(two_bp, branch.name)
            end
        end
    end
    return zero_bp, one_bp, two_bp
end