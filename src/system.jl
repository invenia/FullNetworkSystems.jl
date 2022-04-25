"""
    $TYPEDEF

Type defining ancillary services time series.  Fields are `KeyedArray` where the keys are
`generator names x datetimes`.  Dollar symbol \$.

Fields:
$TYPEDFIELDS
"""
struct ServicesTimeSeries
    "Regulation offer prices (\$ /MW)"
    reg::KeyedArray{Float64, 2}
    "Spinning offer prices (\$ /MW)"
    spin::KeyedArray{Float64, 2}
    "Supplemental on offer prices (\$ /MW)"
    sup_on::KeyedArray{Float64, 2}
    "Supplemental off offer prices (\$ /MW)"
    sup_off::KeyedArray{Float64, 2}
end

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
    "Zonal regulation requirement (MWs)"
    reg::Float64
    "Zonal spinning requirement (MWs)"
    spin::Float64
    "Zonal supplemental on requirement (MWs)"
    sup_on::Float64
    "Zonal supplemental off requirement (MWs)"
    sup_off::Float64
end

###### Static Component Types ######

abstract type StaticComponent end

Base.length(components::StaticComponent) = length(getfield(components, 1))
# define interfaces? Iterator? Table?

"""
    $TYPEDEF

Type for static generator component attributes (i.e. things that describe a generator that
are not time series data).

Fields:
$TYPEDFIELDS
"""
struct Generators <: StaticComponent
    "Generator ids/unit codes"
    name::Vector{Int}
    "Number of the zone the generator is located in"
    zone::Vector{Int}
    "Cost of turning on the generator (\$)"
    startup_cost::Vector{Float64}
    "Cost of turning off the generator (\$)"
    shutdown_cost::Vector{Float64}
    "Cost of the generator being on but not producing any MW (\$ /hour)"
    no_load_cost::Vector{Float64}
    "Hours each generator has been at its current status at the start of the day"
    hours_at_status::Vector{Float64}
    "Minimum time a generator has to be committed for (hours)"
    min_uptime::Vector{Float64}
    "Minimum time a generator has to be off for (hours)"
    min_downtime::Vector{Float64}
    "Rate at which a generator can increase generation (MW/minute)"
    ramp_up::Vector{Float64}
    "Rate at which a generator can decrease generation (MW/minute)"
    ramp_down::Vector{Float64}
    "Generation of generators at the start of the day (MWs)"
    initial_gen::Vector{Float64} # this one changes in RT with _update_system_generation - but is that necessary - could be a mutable time series?
    "Symbol describing the technology of a generator"
    technology::Vector{Symbol}
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
    $TYPEDEF

Type for static bus component attributes.

Fields:
$TYPEDFIELDS
"""
struct Buses <: StaticComponent
    "Bus name"
    name::Vector{InlineString15}
    "Base volatge (kV)"
    base_voltage::Vector{Float64}
end

"""
    $TYPEDEF

Type for static branch component attributes.  Branches may have between 0 and 2 break points
which is why the `break_points` and `penalties` fields contain variable length `Tuple`s.

Fields:
$TYPEDFIELDS
"""
struct Branches <: StaticComponent
    "Branch long name"
    name::Vector{InlineString31}
    "Name of the bus the branch goes to"
    to_bus::Vector{InlineString15}
    "Name of the bus the branche goes from"
    from_bus::Vector{InlineString15}
    "Power flow limit for the base case (MVA)"
    rate_a::Vector{Float64}
    "Power flow limit for contingency scenario (MVA)"
    rate_b::Vector{Float64}
    "Boolean defining whether the branch is monitored"
    is_monitored::Vector{Bool}
    "Break points of the branch. Branches can have 0, 1, or 2 break points"
    break_points::Vector{Tuple{Vararg{Float64}}} # variable length (0, 1, 2)
    "Price penalties for each of the break points of the branch (\$)"
    penalties::Vector{Tuple{Vararg{Float64}}} # length corresponding to number of break points
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

"""
    System

The abstract type for representing the whole power system including topology, static
components and their attributes, and time series data.

Topology: `Dict`s linking generators, loads, and bids (if present) to buses.
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
    "`Dict` where the keys are bus names and the values are generator ids at that bus"
    gens_per_bus::Dict{InlineString15, Vector{Int}}
    "`Dict` where the keys are bus names and the values are increment bid ids at that bus"
    incs_per_bus::Dict{InlineString15, Vector{String}}
    "`Dict` where the keys are bus names and the values are decrement bid ids at that bus"
    decs_per_bus::Dict{InlineString15, Vector{String}}
    "`Dict` where the keys are bus names and the values are price sensitive demand ids at that bus"
    psds_per_bus::Dict{InlineString15, Vector{String}}
    "`Dict` where the keys are bus names and the values are load ids at that bus"
    loads_per_bus::Dict{InlineString15, Vector{String}}

    "Zones in the `System`, which will also include a `Zone` entry for the market wide zone"
    zones::Vector{Zone}
    buses::Buses
    generators::Generators
    branches::Branches
    """
    The line outage distribution factor matrix of the system for a set of contingencies given
    by the keys of the `Dict`. Each entry is a `KeyedArray` with axis keys
    `branch names x branch on outage`
    """
    LODF::Dict{String, KeyedArray{Float64, 2}}
    """
    Power transfer distribution factor of the system.  `KeyedArray` where the axis keys are
    `branch names x bus names`
    """
    PTDF::KeyedArray{Float64, 2}

    # Generator related time series
    "Generator offer curves. `KeyedArray` where the axis keys are `generator names x datetimes`"
    offer_curve::KeyedArray{Vector{Tuple{Float64, Float64}}, 2}
    "Generator availability"
    availability::KeyedArray{Bool, 2}
    "Generator must run flag indicating that the generator has to be committed at that hour"
    must_run::KeyedArray{Bool, 2}
    "Generator minimum output in the ancillary services market (MWs)"
    regulation_min::KeyedArray{Float64, 2}
    "Generator maximum output in the ancillary services market (MWs)"
    regulation_max::KeyedArray{Float64, 2}
    "Generator minimum output (MWs)"
    pmin::KeyedArray{Float64, 2}
    "Generator maximum output (MWs)"
    pmax::KeyedArray{Float64, 2}
    "Time series data for ancillary services provided by generators"
    ancillary_services::ServicesTimeSeries

    # Load time series
    "Load time series data. `KeyedArray` where the axis keys are `load ids x datetimes`"
    loads::KeyedArray{Float64, 2}

    # Virtuals/PSD time series
    "Increment bids time series data. `KeyedArray` where the axis keys are `bid ids x datetimes`"
    increment_bids::KeyedArray{Vector{Tuple{Float64, Float64}}, 2}
    "Decrement bids time series data. `KeyedArray` where the axis keys are `bid ids x datetimes`"
    decrement_bids::KeyedArray{Vector{Tuple{Float64, Float64}}, 2}
    "Price sensitive demand time series data. `KeyedArray` where the axis keys are `bid ids x datetimes`"
    price_sensitive_demand::KeyedArray{Vector{Tuple{Float64, Float64}}, 2}
end

"""
    $TYPEDEF

Subtype of a `System` for modelling the real-time market.

Fields:
$TYPEDFIELDS
"""
struct SystemRT <: System
    "`Dict` where the keys are bus names and the values are generator ids at that bus"
    gens_per_bus::Dict{InlineString15, Vector{Int}}
    "`Dict` where the keys are bus names and the values are load ids at that bus"
    loads_per_bus::Dict{InlineString15, Vector{String}}

    "Zones in the `System`, which will also include a `Zone` entry for the market wide zone"
    zones::Vector{Zone}
    buses::Buses
    generators::Generators
    branches::Branches
    """
    The line outage distribution factor matrix of the system for a set of contingencies given
    by the keys of the `Dict`. Each entry is a `KeyedArray` with axis keys
    `branch names x branch on outage`
    """
    LODF::Dict{String, KeyedArray{Float64, 2}}
    """
    Power transfer distribution factor of the system.  `KeyedArray` where the axis keys are
    `branch names x bus names`
    """
    PTDF::KeyedArray{Float64, 2}

    # Generator related time series
    "Generator offer curves. `KeyedArray` where the axis keys are `generator names x datetimes`"
    offer_curve::KeyedArray{Vector{Tuple{Float64, Float64}}, 2}
    "Generator status indicated by a `Bool`"
    status::KeyedArray{Bool, 2}
    "Generator ancillary service status indicated by a `Bool`"
    status_regulation::KeyedArray{Bool, 2}
    "Generator minimum output in the ancillary services market (MWs)"
    regulation_min::KeyedArray{Float64, 2}
    "Generator maximum output in the ancillary services market (MWs)"
    regulation_max::KeyedArray{Float64, 2}
    "Generator minimum output (MWs)"
    pmin::KeyedArray{Float64, 2}
    "Generator maximum output (MWs)"
    pmax::KeyedArray{Float64, 2}
    "Time series data for ancillary services provided by generators"
    ancillary_services::ServicesTimeSeries

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
    return axiskeys(system.offer_curve, 2)
end
