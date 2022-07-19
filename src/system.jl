const MARKET_WIDE_ZONE = -9999
const BidName = InlineString31
const ZoneNum = Int64

"""
    $TYPEDEF

Type defining a market zone.  The `Zone` is identified by a number.  The other fields contain
the service requirements for the zone.  Requirements are given in `pu` assuming a base power
of 100MW.

Fields:
$TYPEDFIELDS
"""
Base.@kwdef struct Zone
    "Zone number"
    number::ZoneNum
    "Zonal regulation requirement (pu)"
    regulation::Float64
    "Zonal operating reserve requirement (regulation + spinning + supplemental) (pu)"
    operating_reserve::Float64
    "Zonal good utility practice requirement (regulation + spinning) (pu)"
    good_utility::Float64
end
const Zones = Dictionary{ZoneNum, Zone}

const UnitCode = Int64
"""
    $TYPEDEF

Type for static generator attribute (i.e. things that describe a generator that are not time
series data).  Parameters given in `pu` assume a base power of 100MW.

Fields:
$TYPEDFIELDS
"""
Base.@kwdef struct Generator
    "Generator id/unit code"
    unit_code::UnitCode
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
    "Rate at which the generator can increase generation (pu/minute)"
    ramp_up::Float64
    "Rate at which the generator can decrease generation (pu/minute)"
    ramp_down::Float64
    "Symbol describing the technology of the generator"
    technology::Symbol
end
const Generators = Dictionary{UnitCode, Generator}

const BusName = InlineString15
"""
    $TYPEDEF

Type for static bus attributes.

Fields:
$TYPEDFIELDS
"""
Base.@kwdef struct Bus
    "Bus name"
    name::BusName
    "Base voltage (kV)"
    base_voltage::Float64
end
const Buses = Dictionary{BusName, Bus}

const BranchName = InlineString31
"""
    $TYPEDEF

Type for static branch attributes.  Branches may have between 0 and 2 break
points which is why the `break_points` and `penalties` fields contain variable length `Tuple`s.

Fields:
$TYPEDFIELDS
"""
Base.@kwdef struct Branch
    "Branch long name"
    name::BranchName
    "Name of the bus the branch goes to"
    to_bus::BusName
    "Name of the bus the branch goes from"
    from_bus::BusName
    "Power flow limit for the base case (pu)"
    rate_a::Float64
    "Power flow limit for contingency scenario (pu)"
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
    "Resistance of the branch (pu)"
    resistance::Float64
    "Reactance of the branch (pu)"
    reactance::Float64
    "Boolean indicating whether the branch is a transformer"
    is_transformer::Bool
    "Ratio between the nominal winding one and two voltages of the transformer"
    tap::Union{Missing, Float64}
    "Phase shift angle (radians)"
    angle::Union{Missing, Float64}
end
const Branches = Dictionary{BranchName, Branch}

"""
Constructors for a `Branch`.  The user has the option to define a `Branch` as a line e.g.
```
line1 = Branch("1", "A", "B", 10.0, 10.0, true, (100.0, 102.0), (5.0, 6.0), 1.0, 1.0)
```
where the final two values (`resistance` and `reactance`) can be left unspecified.  Or the
user can define a `Branch`` as a transformer:
```
trnasformer1 = Branch(
    "4", "A", "C", 10.0, 10.0, true, (100.0, 102.0), (5.0, 6.0), 1.0, 1.0, 0.5, 30.0
)
```
where two extra parameters are provided as the end representing `tap` and `angle`.
"""
function Branch(
    name,
    to_bus,
    from_bus,
    rate_a,
    rate_b,
    is_monitored,
    break_points,
    penalities,
    resistance=0.0,
    reactance=0.0
)
    tap = missing
    angle = missing
    is_transformer = false
    return Branch(
        name,
        to_bus,
        from_bus,
        rate_a,
        rate_b,
        is_monitored,
        break_points,
        penalities,
        resistance,
        reactance,
        is_transformer,
        tap,
        angle
    )
end

function Branch(
    name,
    to_bus,
    from_bus,
    rate_a,
    rate_b,
    is_monitored,
    break_points,
    penalities,
    resistance,
    reactance,
    tap::Float64,
    angle::Float64
)
    is_transformer = true
    return Branch(
        name,
        to_bus,
        from_bus,
        rate_a,
        rate_b,
        is_monitored,
        break_points,
        penalities,
        resistance,
        reactance,
        is_transformer,
        tap,
        angle
    )
end

###### Time Series types ######

"""
    $TYPEDEF

Generator related time series data that is needed for both the day-ahead and real-time formulations.
Values given in `pu` assume a base power of 100MW.

Fields:
$TYPEDFIELDS
"""
Base.@kwdef struct GeneratorTimeSeries
    "Generation of the generator at the start of the time period (pu)"
    initial_generation::KeyedArray{Float64, 1}
    "Generator offer curves. `KeyedArray` where the axis keys are `generator names x datetimes`"
    offer_curve::KeyedArray{Vector{Tuple{Float64, Float64}}, 2}
    "Generator minimum output in the ancillary services market (pu)"
    regulation_min::KeyedArray{Float64, 2}
    "Generator maximum output in the ancillary services market (pu)"
    regulation_max::KeyedArray{Float64, 2}
    "Generator minimum output (pu)"
    pmin::KeyedArray{Float64, 2}
    "Generator maximum output (pu)"
    pmax::KeyedArray{Float64, 2}
    """
    Ancillary services regulation offer prices (\$ /pu). Generators not providing the service
    will have `missing` offer data
    """
    asm_regulation::KeyedArray{Union{Missing, Float64}, 2}
    """
    Ancillary services spinning offer prices (\$ /pu). Generators not providing the service
    will have `missing` offer data
    """
    asm_spin::KeyedArray{Union{Missing, Float64}, 2}
    """
    Ancillary services supplemental on offer prices (\$ /pu). Generators not providing the service
    will have `missing` offer data
    """
    asm_sup_on::KeyedArray{Union{Missing, Float64}, 2}
    """
    Ancillary services supplemental off offer prices (\$ /pu). Generators not providing the service
    will have `missing` offer data
    """
    asm_sup_off::KeyedArray{Union{Missing, Float64}, 2}
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
Base.@kwdef struct GeneratorStatusDA <: GeneratorStatus
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
Base.@kwdef struct GeneratorStatusRT <: GeneratorStatus
    "Generator commitment status indicated by a `Bool`"
    status::KeyedArray{Bool, 2}
    "Generator regulation commitment status indicated by a `Bool`"
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
Base.@kwdef mutable struct SystemDA <: System
    "`Dictionary` where the keys are bus names and the values are generator ids at that bus"
    gens_per_bus::Dictionary{BusName, Vector{Int}}
    "`Dictionary` where the keys are bus names and the values are increment bid ids at that bus"
    incs_per_bus::Dictionary{BusName, Vector{BidName}}
    "`Dictionary` where the keys are bus names and the values are decrement bid ids at that bus"
    decs_per_bus::Dictionary{BusName, Vector{BidName}}
    """
    `Dictionary` where the keys are bus names and the values are price sensitive demand bid
    ids at that bus
    """
    psds_per_bus::Dictionary{BusName, Vector{BidName}}
    "`Dictionary` where the keys are bus names and the values are load ids at that bus"
    loads_per_bus::Dictionary{BusName, Vector{BidName}}

    "Zones in the `System`, which will also include a `Zone` entry for the market wide zone"
    zones::Zones
    "Buses in the `System` indexed by bus name"
    buses::Buses
    "Generators in the `System` indexed by unit code"
    generators::Generators
    "Branches in the `System` indexed by branch name"
    branches::Branches
    """
    The line outage distribution factor matrix of the system for a set of contingencies given
    by the keys of the `Dictionary`. Each entry is a `KeyedArray` with axis keys
    `branch names x branch on outage`
    """
    lodf::Dictionary{String, KeyedArray{Float64, 2}}
    """
    Power transfer distribution factor of the system.  `KeyedArray` where the axis keys are
    `branch names x bus names`
    """
    ptdf::Union{KeyedArray{Float64, 2}, Missing}

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
Base.@kwdef mutable struct SystemRT <: System
    "`Dictionary` where the keys are bus names and the values are generator ids at that bus"
    gens_per_bus::Dictionary{BusName, Vector{Int}}
    "`Dictionary` where the keys are bus names and the values are load ids at that bus"
    loads_per_bus::Dictionary{BusName, Vector{BidName}}

    "Zones in the `System`, which will also include a `Zone` entry for the market wide zone"
    zones::Zones
    "Buses in the `System` indexed by bus name"
    buses::Buses
    "Generators in the `System` indexed by unit code"
    generators::Generators
    "Branches in the `System` indexed by branch name"
    branches::Branches
    """
    The line outage distribution factor matrix of the system for a set of contingencies given
    by the keys of the `Dictionary`. Each entry is a `KeyedArray` with axis keys
    `branch names x branch on outage`
    """
    lodf::Dictionary{String, KeyedArray{Float64, 2}}
    """
    Power transfer distribution factor of the system.  `KeyedArray` where the axis keys are
    `branch names x bus names`
    """
    ptdf::Union{KeyedArray{Float64, 2}, Missing}

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
        elseif type <: KeyedArray && name != :ptdf
            print(io, "$name, ")
        end
    end
    return nothing
end
