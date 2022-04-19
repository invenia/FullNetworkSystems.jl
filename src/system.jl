"""
    ServicesTimeSeries(reg, spin, sup_on, sup_off)

Type defining services time series.  Fields are KeyedArray where the keys are generator names
x datetimes.  Only generators that provide each service are included in the array.
"""
struct ServicesTimeSeries
    reg::KeyedArray{Float64}
    spin::KeyedArray{Float64}
    sup_on::KeyedArray{Float64}
    sup_off::KeyedArray{Float64}
end

"""
    Zone(number, reg, spin, sup_on, sup_off)

Type defining a market zone.  The `Zone` is identified by a number.  The other fields contain
the service requirements for the zone.
"""
struct Zone
    number::Int64
    reg::Float64
    spin::Float64
    sup_on::Float64
    sup_off::Float64
end

###### Static Component Types ######

abstract type StaticComponent end

Base.length(components::StaticComponent) = length(getfield(components, 1))
# define iterators interface? or Tables interface?

"""
    Generators(
        name::Vector{Int}
        zone::Vector{Int}
        startup_cost::Vector{Float64}
        shutdown_cost::Vector{Float64}
        no_load_cost::Vector{Float64}
        time_at_status::Vector{Float64}
        min_uptime::Vector{Float64}
        min_downtime::Vector{Float64}
        ramp_up::Vector{Float64}
        ramp_down::Vector{Float64}
        initial_gen::Vector{Float64}
        technology::Vector{Symbol}
    )

Type for static generator component attributes (i.e. things that describe a generator that
are not time series data).
"""
struct Generators <: StaticComponent
    name::Vector{Int}
    zone::Vector{Int}
    startup_cost::Vector{Float64}
    shutdown_cost::Vector{Float64}
    no_load_cost::Vector{Float64}
    time_at_status::Vector{Float64}
    min_uptime::Vector{Float64}
    min_downtime::Vector{Float64}
    ramp_up::Vector{Float64}
    ramp_down::Vector{Float64}
    initial_gen::Vector{Float64} # this one changes in RT with _update_system_generation - but is that necessary - it could be a mutable time series
    technology::Vector{Symbol} # or we could define some types for this if we like
end

"""
    Buses(name, base_voltage)

Type for static bus component attributes.
"""
struct Buses <: StaticComponent
    name::Vector{String}
    base_voltage::Vector{Float64}
end

"""
    Branches(
        name::Vector{String}
        to_bus::Vector{String}
        from_bus::Vector{String}
        rate_a::Vector{Float64}
        rate_b::Vector{Float64}
        is_monitored::Vector{Bool}
        break_points::Vector{Tuple{Vararg{Float64}}}
        penalties::Vector{Tuple{Vararg{Float64}}}
    )

Type for static branch component attributes.  Branches may have between 0 and 2 break points
which is why the `break_points` and `penalties` fields contain variable length `Tuple`s.
"""
struct Branches <: StaticComponent
    name::Vector{String}
    to_bus::Vector{String}
    from_bus::Vector{String}
    rate_a::Vector{Float64}
    rate_b::Vector{Float64}
    is_monitored::Vector{Bool}
    break_points::Vector{Tuple{Vararg{Float64}}} # variable length (0, 1, 2)
    penalties::Vector{Tuple{Vararg{Float64}}} # length corresponding to number of break points
end

"""
    System

The big type that represents the whole power system.

Topology section: `Dict`s linking generators, loads, and bids to buses.
System wide static attributes: zones, buses, generators, branches, LODF and PTDF.
Time series data: all the time series associated with generators, loads and bids.  All stored
as `KeyedArray`s of `names x datetimes`.
"""
struct System
    gens_per_bus::Dict{Int, Vector{Int}} # Are buses going to be named by string or number?
    incs_per_bus::Dict{Int, Vector{String}}
    decs_per_bus::Dict{Int, Vector{String}}
    psds_per_bus::Dict{Int, Vector{String}}
    loads_per_bus::Dict{Int, Vector{String}}

    zones::Vector{Zone} # zones contain the time series data for services
    buses::Buses
    generators::Generators
    branches::Branches
    LODF::Dict{String, KeyedArray}
    PTDF::KeyedArray

    # Generator related time series
    offer_curve::KeyedArray{Vector{Tuple{Float64, Float64}}}
    availability::KeyedArray{Bool}
    must_run::KeyedArray{Bool}
    regulation_min::KeyedArray{Float64}
    regulation_max::KeyedArray{Float64}
    pmin::KeyedArray{Float64}
    pmax::KeyedArray{Float64}
    ancillary_services::ServicesTimeSeries

    # Load time series
    loads::KeyedArray{Float64}

    # Virtuals/PSD time series
    increment_bids::KeyedArray{Vector{Tuple{Float64, Float64}}} # in DA but not in RT
    decrement_bids::KeyedArray{Vector{Tuple{Float64, Float64}}}
    price_sensitive_demand::KeyedArray{Vector{Tuple{Float64, Float64}}}
end

struct SystemRT
    gens_per_bus::Dict{Int, Vector{Int}} # Are buses going to be named by string or number?
    loads_per_bus::Dict{Int, Vector{String}}

    zones::Vector{Zone} # zones contain the time series data for services
    buses::Buses
    generators::Generators
    branches::Branches
    LODF::Dict{String, KeyedArray}
    PTDF::KeyedArray

    # Generator related time series
    offer_curve::KeyedArray{Vector{Tuple{Float64, Float64}}}
    status::KeyedArray{Bool} # used in RT but not in DA
    status_regulation::KeyedArray{Bool} # do we need this or is it contained in ancillary_services?
    regulation_min::KeyedArray{Float64}
    regulation_max::KeyedArray{Float64}
    pmin::KeyedArray{Float64}
    pmax::KeyedArray{Float64}
    ancillary_services::ServicesTimeSeries

    # Load time series
    loads::KeyedArray{Float64}
end

function Base.show(io::IO, ::MIME"text/plain", system::T) where {T <: System}
    Base.summary(io, system)
    get(io, :compact, false) && return nothing
    z = length(system.zones) - 1
    print(io, " with $z Zones")
    for c in [:buses, :generators, :branches]
        l = length(getproperty(getproperty(system, c), :name))
        print(io, ", $l $(c)")
    end
    print(io, "\n")
    print(io, "Included time series: ")
    for (name, type) in zip(fieldnames(T), fieldtypes(T))
        if name == last(fieldnames(T))
            print(io, "$name")
        elseif type <: KeyedArray
            print(io, "$name, ")
        end
    end
    return nothing
end
