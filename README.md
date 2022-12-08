# FullNetworkSystems

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://invenia.github.io/FullNetworkSystems.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://invenia.github.io/FullNetworkSystems.jl/dev)
[![Build Status](https://github.com/invenia/FullNetworkSystems.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/invenia/FullNetworkSystems.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/invenia/FullNetworkSystems.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/invenia/FullNetworkSystems.jl)
[![Code Style: Blue](https://img.shields.io/badge/code%20style-blue-4495d1.svg)](https://github.com/invenia/BlueStyle)
[![ColPrac: Contributor's Guide on Collaborative Practices for Community Packages](https://img.shields.io/badge/ColPrac-Contributor's%20Guide-blueviolet)](https://github.com/SciML/ColPrac)

This package defines a set of types and data structures to represent an energy grid and the components within it.
The types defined can be used to build Optimal Power Flow (OPF) and associated optimisation problems e.g. unit commitment and economic dispatch.
The data structures are designed so that the relevant data can be easily accessed and used to formulate these optimisation problems.

## Features of the System

The `System` subtypes (`SystemDA` and `SystemRT`) both contain fields which represent static components of an energy grid.
Firstly, the `Generator` type has a `unit_code` field identifying the generator and fields for attributes that do not change over time e.g. ramps rates, minimum up- and down-time, and technology.

```julia
generator = Generator(
    unit_code=111,
    zone=1,
    startup_cost=0.0,
    shutdown_cost=1.0,
    no_load_cost=1.0,
    min_uptime=24.0,
    min_downtime=24.0,
    ramp_up=2.0,
    ramp_down=2.0,
    technology=:steam_turbine
)
```
The `Bus` and `Branch` types can be used to model bus injection and branch flow constraints (see this [blog post](https://invenia.github.io/blog/2021/06/18/opf-intro/) introducing these OPF modelling concepts).
These types store attributes of buses and branches that do not change over time.
The `to_bus` and `from_bus` fields in the `Branch` type can be used to create a network map of which branches connect which buses.

```julia
bus_a = Bus(name="A", base_voltage=100.0)
bus_c = Bus(name="C", base_voltage=100.0)

branch = Branch(
    name="1",
    to_bus="A",
    from_bus="C",
    rate_a=10.0,
    rate_b=10.0,
    is_monitored=true,
    break_points=(100.0, 102.0),
    penalties=(5.0, 6.0),
    resistance=1.0,
    reactance=1.0
)
```
The fields `gens_per_bus`, `loads_per_bus` etc. provide topological information about the energy grid by mapping which buses components in the system are located at.
Each mapping is in the form of a `Dictionary` where the keys are bus names and the values are vectors of component identifiers (e.g. `Generator` `unit_code`s).

Along with the static attributes and topology information the `System` types include fields for time series data.
Firstly there are the time series associated with generators defined in a `GeneratorTimeSeries`.
One particular time series to note is the `offer_curve`, which represents the offers of generation submitted by each generator for each hour.
This time series is expected to be a `KeyedArray` where the dimensions are `generator ids x datetimes` and the fields are vectors of (price, volume) pairs.
```julia
generator_ids = [111, 222, 333]
datetimes = DateTime(2017, 12, 15):Hour(1):DateTime(2017, 12, 15, 23)
gen_time_series = GeneratorTimeSeries(;
    initial_generation = KeyedArray(fill(100.0, length(generator_ids)); generator_ids),
    offer_curve = KeyedArray(fill([(1.0, 100.0)], length(generator_ids), length(datetimes)); generator_ids, datetimes)
    ...
)
```
The `GeneratorTimeSeries` type includes fields for additional time series such as generation limits, ramp limits and ancillary service offers, which means these features can be included in an optimisation problem (see [`GeneratorTimeSeries`](https://invenia.github.io/FullNetworkSystems.jl/stable/#FullNetworkSystems.GeneratorTimeSeries) for details of all the time series fields).
`GeneratorStatus` types also contain time series data, specifically associated with the status of the generator (e.g. whether it is on or off, how long it has been on or off).
This is useful for including factors such as ramp rates in an optimisation problem, as the status of a generator limits how much it can ramp up or down in a given hour.

The `SystemDA` type includes fields for additional supply (`increment`) and demand (`decrement`, `price_sensitive_loads`) bids for the purpose of modelling virtual participation in electricity markets ([introduction to virtual bidding](https://hepg.hks.harvard.edu/publications/virtual-bidding-and-electricity-market-design)).
The bid data is expected to be a `KeyedArray` where the dimensions are `ids x datetimes` and the fields are vectors of price-volume pairs, as in the offer curves.
```julia
bid_ids = ["123", "456", "789"] # unique identifers
datetimes = DateTime(2017, 12, 15):Hour(1):DateTime(2017, 12, 15, 23)
increments = KeyedArray(
    fill([(0.1, 10.0)], length(generator_ids), length(datetimes)); bid_ids, datetimes
)
```

## Grid Matrices

This package also provides functions to calculate the Power Transfer Distribution Factor (PTDF) and Line Outage Distribution Factor (LODF) matrices for a `System` of branches and buses.
These matrices are useful for modelling branch flow constraints under different contingency scenarios.
The `System` types have fields to store these matrices.

## Example Modelling Problem

The following is an example of how the data stored in a `SystemRT` object can be used to build a JuMP model.
The objective of the model is to solve a simple energy balance problem, where a set of loads (demands) need to be met by generation (supply), for the minimum possible cost.
Assume we have built all the components of the system described in the previous sections so that we can construct an instance of a system (see [`SystemRT`](https://invenia.github.io/FullNetworkSystems.jl/stable/#FullNetworkSystems.SystemRT) for specific details of the components in a `SystemRT`).

```julia
using AxisKeys
using FullNetworkSystems
using HiGHS
using JuMP

system = SystemRT(
    gens_per_bus,
    loads_per_bus,
    zones,
    buses,
    generators,
    branches,
    lodfs,
    ptdf,
    generator_time_series,
    generator_status,
    loads
)

model = Model()
units = keys(get_generators(system))
datetimes = get_datetimes(system)

@variable(model, generation[u in units, t in datetimes] >= 0)

load = get_loads(system)
@constraint(
    model,
    energy_balance[t in datetimes],
    sum(model[:generation][u, t] for u in units) == sum(load(l, t) for l in axiskeys(load, 1))
)

# for simplicity, use a fixed price per MW, rather than a variable price offer curve
offer_curves = get_offer_curve(system)
prices = map(curve -> only(first.(curve)), offer_curves)
cost = AffExpr()
for u in units, t in datetimes
    add_to_expression!(cost, prices(u, t), model[:generation][u, t])
end

@objective(model, Min, cost)

set_optimizer(model, HiGHS.Optimizer)
optimize!(model)
```
