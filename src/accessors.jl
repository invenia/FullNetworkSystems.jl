"""
    get_datetimes(system)

Extract datetimes from a `System`.
"""
function get_datetimes(system::System)
    # use offer_curve axiskeys because all subtypes of System have offer_curve
    return axiskeys(system.generator_time_series.offer_curve, 2)
end


get_system_requirements(system::SystemDA) = system.requirements

"Returns a `Dictionary` with zonal regulation requirements indexed by zone number."
function get_regulation_requirements(requirements::ZonalRequirements)
    return map(requirements) do zone
        zone.regulation
    end
end

"Returns a `Dictionary` with zonal operating reserve requirements indexed by zone number."
function get_operating_reserve_requirements(requirements::ZonalRequirements)
    return map(requirements) do zone
        zone.operating_reserve
    end
end

"Returns a `Dictionary` with zonal good utility practice requirements indexed by zone number."
function get_good_utility_requirements(requirements::ZonalRequirements)
    return map(requirements) do zone
        zone.good_utility
    end
end

get_regulation_up_requirement(requirements::SystemWideRequirements) = requirements.regulation_up

get_regulation_down_requirement(requirements::SystemWideRequirements) = requirements.regulation_down

get_responsive_requirement(requirements::SystemWideRequirements) = requirements.responsive_regulation

get_non_spinning_requirement(requirements::SystemWideRequirements) = requirements.non_spinning


"Returns a `Dictionary` of `Bus` objects in the `System` indexed by bus name."
get_buses(system::System) = system.buses
"Returns a `Dictionary` of `Generator` objects in the `System` indexed by unit code."
get_generators(system::System) = system.generators
"Returns a `Dictionary` of `Branch` objects in the `System` indexed by branch name."
get_branches(system::System) = system.branches
"Returns a `Dictionary` of branches that are not transformers in the `System` indexed by name."
get_lines(system::System) = filter(br -> !br.is_transformer, system.branches)
"Returns a `Dictionary` of transformers in the `System` indexed by name."
get_transformers(system::System) = filter(br -> br.is_transformer, system.branches)

"Returns a `Dictionary` of unit codes at each bus."
get_gens_per_bus(system::System) = system.gens_per_bus
"Returns a `Dictionary` of load names at each bus."
get_loads_per_bus(system::System) = system.loads_per_bus

"Returns the power transfer distribution factor of the system."
get_ptdf(system::System) = system.ptdf
"Returns the power transfer distribution factor of the system. Calculates it if missing from system"
retrieve_ptdf(system::System) = coalesce(get_ptdf(system), compute_ptdf(system))

"Returns a `Dictionary` of the line outage distribution factor matrices for the `System` indexed by contingencies."
get_lodfs(system::System) = system.lodfs

"Returns the generation of the generator at the start of the time period (pu)"
get_initial_generation(system::System) = system.generator_time_series.initial_generation
"Returns time series data of the fixed loads in the system"
get_fixed_loads(system::System) = system.loads
"Returns time series data of the generator offer curves"
get_offer_curve(system::System) = system.generator_time_series.offer_curve
"Returns time series data of minimum generator output (pu)"
get_pmin(system::System) = system.generator_time_series.pmin
"Returns time series data of maximum generator output (pu)"
get_pmax(system::System) = system.generator_time_series.pmax
"Returns time series data of minimum generator output in the ancillary services market (pu)"
get_regulation_min(system::System) = system.generator_time_series.regulation_min
"Returns time series data of maximum generator output in the ancillary services market (pu)"
get_regulation_max(system::System) = system.generator_time_series.regulation_max


get_ancillary_services(system::SystemDA) = system.generator_time_series.ancillary_services

"Returns time series data of offer prices for ancillary servives regulation reserves (\$ /pu)"
get_regulation_offers(ancillary_services::FourServices) = ancillary_services.regulation_offers
"Returns time series data of offer prices for ancillary servives spinning reserves (\$ /pu)"
get_spinning_offers(ancillary_services::FourServices) = ancillary_services.spinning_offers
"Returns time series data of offer prices for ancillary servives online supplemental reserves (\$ /pu)"
get_on_supplemental_offers(ancillary_services::FourServices) = ancillary_services.on_supplemental_offers
"Returns time series data of offer prices for ancillary servives offline supplemental reserves (\$ /pu)"
get_off_supplemental_offers(ancillary_services::FourServices) = ancillary_services.off_supplemental_offers

get_regulation_up_offers(ancillary_services::FiveServices) = ancillary_services.regulation_up_offers

get_regulation_down_offers(ancillary_services::FiveServices) = ancillary_services.regulation_down_offers

get_responsive_regulation_offers(ancillary_services::FiveServices) = ancillary_services.responsive_regulation_offers

get_on_nonspinning_offers(ancillary_services::FiveServices) = ancillary_services.on_nonspinning_offers

get_off_nonspinning_offers(ancillary_services::FiveServices) = ancillary_services.off_nonspinning_offers


get_load_pmin(load_timeseries::LoadTimeSeries) = load_timeseries.pmin

get_load_pmax(load_timeseries::LoadTimeSeries) = load_timeseries.pmax

get_load_ancillary_services(system::SystemDA) = system.load_services.ancillary_services

"Returns a flag indicating whether each generator was on at the start of the day."
function get_initial_commitment(system::SystemDA)
    return map(system.generator_time_series.initial_generation) do i
        i == 0.0 ? false : true
    end
end

"Returns the number of hours each generator was on at the start of the day."
function get_initial_uptime(system::SystemDA)
    return system.generator_status.hours_at_status .* get_initial_commitment(system)
end

"Returns the number of hours each generator was off at the start of the day."
function get_initial_downtime(system::SystemDA)
    return system.generator_status.hours_at_status .* .!get_initial_commitment(system)
end

"Returns a `Dictionary` of increment bids at each bus."
get_incs_per_bus(system::SystemDA) = system.incs_per_bus
"Returns a `Dictionary` of decrement bids at each bus."
get_decs_per_bus(system::SystemDA) = system.decs_per_bus
"Returns a `Dictionary` of price sensitive load bids at each bus."
get_psls_per_bus(system::SystemDA) = system.psls_per_bus

"Returns time series data of increment bids."
get_increments(system::SystemDA) = system.increments
"Returns time series data of decrement bids."
get_decrements(system::SystemDA) = system.decrements
"Returns time series data of price sensitive load bids."
get_price_sensitive_loads(system::SystemDA) = system.price_sensitive_loads
"Returns time series data of both increment bids and decrement bids."
get_virtuals(system::SystemDA) = vcat(system.increments, system.decrements)

"Returns time series data of flags indicating if the generator is available to be committed in each hour"
get_availability(system::SystemDA) = system.generator_status.availability
"Returns time series data of flags indicating if the generator must be committed in each hour"
get_must_run(system::SystemDA) = system.generator_status.must_run

"Returns time series data of generator commitment status in each hour"
get_commitment(system::SystemRT) = system.generator_status.commitment
"Returns time series data of generator regulation commitment status in each hour"
get_regulation_commitment(system::SystemRT) = system.generator_status.regulation_commitment

"""
    gens_per_zone(system::System)

Returns a `Dict` with keys of `Zone` numbers and values of generator names in that zone.
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
    branches_by_breakpoints(system::System) -> NTuple{3, Vector{$BranchName}}

Returns three vectors containing of the names of branches which have 0, 1, and 2 breakpoints.
"""
function branches_by_breakpoints(system::System)
    zero_bp, one_bp, two_bp = BranchName[], BranchName[], BranchName[]
    for branch in system.branches
        if branch.is_monitored
            if all(iszero, branch.break_points)
                push!(zero_bp, branch.name)
            elseif iszero(last(branch.break_points))
                push!(one_bp, branch.name)
            else
                push!(two_bp, branch.name)
            end
        end
    end
    return zero_bp, one_bp, two_bp
end
