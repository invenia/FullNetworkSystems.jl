const MARKET_WIDE_ZONE = -9999
"""
    $TYPEDEF

Type defining a market zone.  The `Zone` is identified by a number.  The other fields contain
the service requirements for the zone.

Fields:
$TYPEDFIELDS
"""
struct Zone
    "Zone number"
    number::Int64
    "Zonal regulation requirement (MW)"
    reg::Float64
    "Zonal spinning requirement (MW)"
    spin::Float64
    "Zonal supplemental on requirement (MW)"
    sup_on::Float64
    "Zonal supplemental off requirement (MW)"
    sup_off::Float64
end

###### Static Component Types ######
const BusName = InlineString15
const BranchName = InlineString31

"""
    $TYPEDEF

Type for static generator attribute (i.e. things that describe a generator that are not time
series data).

Fields:
$TYPEDFIELDS
"""
struct Generator
    "Generator id/unit code"
    unit_code::Int
    "Number of the zone the generator is located in"
    zone::Int
    "Cost of turning on the generator (\$)"
    startup_cost::Float64
    "Cost of turning off the generator (\$)"
    shutdown_cost::Float64
    "Cost of the generator being on but not producing any MW (\$ /hour)"
    no_load_cost::Float64
    "Minimum time the generator has to be committed for (hours)"
    min_uptime::Float64
    "Minimum time the generator has to be off for (hours)"
    min_downtime::Float64
    "Rate at which the generator can increase generation (MW/minute)"
    ramp_up::Float64
    "Rate at which the generator can decrease generation (MW/minute)"
    ramp_down::Float64
    "Symbol describing the technology of the generator"
    technology::Symbol
end

"""
    $TYPEDEF

Type for static bus attributes.

Fields:
$TYPEDFIELDS
"""
struct Bus
    "Bus name"
    name::BusName
    "Base voltage (kV)"
    base_voltage::Float64
end

"""
    $TYPEDEF

Type for static branch attributes.  Branches may have between 0 and 2 break points
which is why the `break_points` and `penalties` fields contain variable length `Tuple`s.

Fields:
$TYPEDFIELDS
"""
struct Branch
    "Branch long name"
    name::BranchName
    "Name of the bus the branch goes to"
    to_bus::BusName
    "Name of the bus the branch goes from"
    from_bus::BusName
    "Power flow limit for the base case (MVA)"
    rate_a::Float64
    "Power flow limit for contingency scenario (MVA)"
    rate_b::Float64
    "Boolean defining whether the branch is monitored"
    is_monitored::Bool
    """
    Break points of the branch. Branches can have 0, 1, or 2 break points. Zeros indicate
    no break point
    """
    break_points::Tuple{Float64, Float64}
    "Price penalties for each of the break points of the branch (\$)"
    penalties::Tuple{Float64, Float64}
end

###### Time Series types ######

"""
    $TYPEDEF

Generator related time series data that is needed for both the day-ahead and real-time formulations.

Fields:
$TYPEDFIELDS
"""
struct GeneratorTimeSeries
    "Generation of the generator at the start of the time period (MW)"
    initial_generation::KeyedArray{Float64, 1}
    "Generator offer curves. `KeyedArray` where the axis keys are `generator names x datetimes`"
    offer_curve::KeyedArray{Vector{Tuple{Float64, Float64}}, 2}
    "Generator minimum output in the ancillary services market (MW)"
    regulation_min::KeyedArray{Float64, 2}
    "Generator maximum output in the ancillary services market (MW)"
    regulation_max::KeyedArray{Float64, 2}
    "Generator minimum output (MW)"
    pmin::KeyedArray{Float64, 2}
    "Generator maximum output (MW)"
    pmax::KeyedArray{Float64, 2}
    "Ancillary services regulation offer prices (\$ /MW)"
    asm_regulation::KeyedArray{Float64, 2}
    "Ancillary services spinning offer prices (\$ /MW)"
    asm_spin::KeyedArray{Float64, 2}
    "Ancillary services supplemental on offer prices (\$ /MW)"
    asm_sup_on::KeyedArray{Float64, 2}
    "Ancillary services supplemental off offer prices (\$ /MW)"
    asm_sup_off::KeyedArray{Float64, 2}
end

"""
    $TYPEDEF

Abstract type for storing time series of generator status information.
"""
abstract type GeneratorStatus end

"""
    $TYPEDEF

Generator status time series data needed for the day-ahead formulation.

Fields:
$TYPEDFIELDS
"""
struct GeneratorStatusDA <: GeneratorStatus
    "Hours each generator has been at its current status at the start of the day"
    hours_at_status::KeyedArray{Float64, 1}
    "Flag indicating if the generator is available to be committed in each hour"
    availability::KeyedArray{Bool, 2}
    "Flag indicating if the generator must be committed in each hour"
    must_run::KeyedArray{Bool, 2}
end

"""
    $TYPEDEF

Generator status time series data needed for the real-time formulation.

Fields:
$TYPEDFIELDS
"""
struct GeneratorStatusRT <: GeneratorStatus
    "Generator status indicated by a `Bool`"
    status::KeyedArray{Bool, 2}
    "Generator regulation status indicated by a `Bool`"
    status_regulation::KeyedArray{Bool, 2}
end

"""
    System

The abstract type for representing the whole power system including topology, static
components and their attributes, and time series data.

Topology: `Dictionaries` linking generators, loads, and bids (if present) to buses.
System wide static components and grid matrices: zones, buses, generators, branches, LODF and PTDF.
Time series data: all the time series associated with generators, loads and bids.  All stored
as `KeyedArray`s of `ids x datetimes`.
"""
abstract type System end

"""
    $TYPEDEF

Subtype of a `System` for modelling the day-ahead market.

Fields:
$TYPEDFIELDS
"""
struct SystemDA <: System
    "`Dictionary` where the keys are bus names and the values are generator ids at that bus"
    gens_per_bus::Dictionary{BusName, Vector{Int}}
    "`Dictionary` where the keys are bus names and the values are increment bid ids at that bus"
    incs_per_bus::Dictionary{BusName, Vector{String}}
    "`Dictionary` where the keys are bus names and the values are decrement bid ids at that bus"
    decs_per_bus::Dictionary{BusName, Vector{String}}
    """
    `Dictionary` where the keys are bus names and the values are price sensitive demand bid
    ids at that bus
    """
    psds_per_bus::Dictionary{BusName, Vector{String}}
    "`Dictionary` where the keys are bus names and the values are load ids at that bus"
    loads_per_bus::Dictionary{BusName, Vector{String}}

    "Zones in the `System`, which will also include a `Zone` entry for the market wide zone"
    zones::Dictionary{Int, Zone}
    "Buses in the `System` indexed by bus name"
    buses::Dictionary{BusName, Bus}
    "Generators in the `System` indexed by unit code"
    generators::Dictionary{Int, Generator}
    "Branches in the `System` indexed by branch name"
    branches::Dictionary{BranchName, Branch}
    """
    The line outage distribution factor matrix of the system for a set of contingencies given
    by the keys of the `Dictionary`. Each entry is a `KeyedArray` with axis keys
    `branch names x branch on outage`
    """
    LODF::Dictionary{String, KeyedArray{Float64, 2}}
    """
    Power transfer distribution factor of the system.  `KeyedArray` where the axis keys are
    `branch names x bus names`
    """
    PTDF::KeyedArray{Float64, 2}

    # Generator related time series
    "Generator related time series data"
    generator_time_series::GeneratorTimeSeries
    "Generator status time series needed for the day-ahead formulation"
    generator_status::GeneratorStatusDA

    # Load time series
    "Load time series data. `KeyedArray` where the axis keys are `load ids x datetimes`"
    loads::KeyedArray{Float64, 2}

    # Virtuals/PSD time series
    "Increment bids time series data. `KeyedArray` where the axis keys are `bid ids x datetimes`"
    increment::KeyedArray{Vector{Tuple{Float64, Float64}}, 2}
    "Decrement bids time series data. `KeyedArray` where the axis keys are `bid ids x datetimes`"
    decrement::KeyedArray{Vector{Tuple{Float64, Float64}}, 2}
    "Price sensitive demand bids time series data. `KeyedArray` where the axis keys are `bid ids x datetimes`"
    price_sensitive_demand::KeyedArray{Vector{Tuple{Float64, Float64}}, 2}
end

"""
    $TYPEDEF

Subtype of a `System` for modelling the real-time market.

Fields:
$TYPEDFIELDS
"""
struct SystemRT <: System
    "`Dictionary` where the keys are bus names and the values are generator ids at that bus"
    gens_per_bus::Dictionary{BusName, Vector{Int}}
    "`Dictionary` where the keys are bus names and the values are load ids at that bus"
    loads_per_bus::Dictionary{BusName, Vector{String}}

    "Zones in the `System`, which will also include a `Zone` entry for the market wide zone"
    zones::Dictionary{Int, Zone}
    "Buses in the `System` indexed by bus name"
    buses::Dictionary{BusName, Bus}
    "Generators in the `System` indexed by unit code"
    generators::Dictionary{Int, Generator}
    "Branches in the `System` indexed by branch name"
    branches::Dictionary{BranchName, Branch}
    """
    The line outage distribution factor matrix of the system for a set of contingencies given
    by the keys of the `Dictionary`. Each entry is a `KeyedArray` with axis keys
    `branch names x branch on outage`
    """
    LODF::Dictionary{String, KeyedArray{Float64, 2}}
    """
    Power transfer distribution factor of the system.  `KeyedArray` where the axis keys are
    `branch names x bus names`
    """
    PTDF::KeyedArray{Float64, 2}

    # Generator related time series
    "Generator related time series data"
    generator_time_series::GeneratorTimeSeries
    "Generator status time series needed for the real-time formulation"
    generator_status::GeneratorStatusRT

    # Load time series
    "Load time series data. `KeyedArray` where the axis keys are `load ids x datetimes`"
    loads::KeyedArray{Float64, 2}
end

function Base.show(io::IO, ::MIME"text/plain", system::T) where {T <: System}
    Base.summary(io, system)
    get(io, :compact, false) && return nothing
    z = length(system.zones) - 1
    print(io, " with $z Zones")
    for c in [:buses, :generators, :branches]
        l = length(getproperty(system, c))
        print(io, ", $l $(c)")
    end
    print(io, "\n")
    print(io, "Included time series: ")
    for (name, type) in zip(fieldnames(T), fieldtypes(T))
        if name == last(fieldnames(T))
            print(io, "$name")
        elseif type <: Union{GeneratorTimeSeries, <:GeneratorStatus}
            for name in fieldnames(type)
                print(io, "$name, ")
            end
        elseif type <: KeyedArray && name != :PTDF
            print(io, "$name, ")
        end
    end
    return nothing
end

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
get_load_timeseries(system::System) = system.loads
"Returns time series data of the generator offer curves"
get_offer_curve_timeseries(system::System) = system.generator_time_series.offer_curve
"Returns time series data of minimum generator output (MW)"
get_pmin_timeseries(system::System) = system.generator_time_series.pmin
"Returns time series data of maximum generator output (MW)"
get_pmax_timeseries(system::System) = system.generator_time_series.pmax
"Returns time series data of minimum generator output in the ancillary services market (MW)"
get_regmin_timeseries(system::System) = system.generator_time_series.regulation_min
"Returns time series data of maximum generator output in the ancillary services market (MW)"
get_regmax_timeseries(system::System) = system.generator_time_series.regulation_max

"Returns time series data of offer prices for ancillary servives regulation (\$ /MW)"
get_regulation_timeseries(system::System) = system.generator_time_series.asm_regulation
"Returns time series data of offer prices for ancillary servives spinning (\$ /MW)"
get_spinning_timeseries(system::System) = system.generator_time_series.asm_spin
"Returns time series data of offer prices for ancillary servives supplemental on (\$ /MW)"
get_supplemental_on_timeseries(system::System) = system.generator_time_series.asm_sup_on
"Returns time series data of offer prices for ancillary servives supplemental off (\$ /MW)"
get_supplemental_off_timeseries(system::System) = system.generator_time_series.asm_sup_off

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
function get_bids_timeseries(system::SystemDA, type_of_bid::Symbol)
    return getproperty(system, type_of_bid)
end

"Returns time series data of flags indicating if the generator is available to be committed in each hour"
get_availability_timeseries(system::SystemDA) = system.generator_status.availability
"Returns time series data of flags indicating if the generator must be committed in each hour"
get_must_run_timeseries(system::SystemDA) = system.generator_status.must_run

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
