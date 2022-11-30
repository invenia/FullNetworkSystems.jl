# FullNetworkSystems

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://invenia.github.io/FullNetworkSystems.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://invenia.github.io/FullNetworkSystems.jl/dev)
[![Build Status](https://github.com/invenia/FullNetworkSystems.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/invenia/FullNetworkSystems.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/invenia/FullNetworkSystems.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/invenia/FullNetworkSystems.jl)
[![Code Style: Blue](https://img.shields.io/badge/code%20style-blue-4495d1.svg)](https://github.com/invenia/BlueStyle)
[![ColPrac: Contributor's Guide on Collaborative Practices for Community Packages](https://img.shields.io/badge/ColPrac-Contributor's%20Guide-blueviolet)](https://github.com/SciML/ColPrac)

This package defines a set of types and data structures to represent an energy grid and the components within it.
The types defined can be used to build Optimal Power Flow and associated optimisation problems e.g. unit commitment and economic dispatch.
The data structures are designed so that the relevant data can be easily accessed and used to formulate these optimisation problems.

## Example Modelling Problem

The following is an example of how the data stored in a `SystemRT` object can be used to build a JuMP model.
The objective of the model is to solve a simple energy balance problem, where a set of loads (demands) need to be met by generation (supply), for the minimum possible cost.
Assume we have an instance of a system (see [`SystemRT`](@ref) for details of all the components in a `SystemRT`).

```julia
using AxisKeys
using FullNetworkSystems
using HiGHS
using JuMP

system = SystemRT(components...)

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

## Additional Features of the System

The `System` types include additional fields which allow for other features of an energy grid to be represented in code and included in an optimisation model.
The `Generator` type has fields for ramps rates, minimum up- and down-time and startup and shutdown costs.

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

The `System` types include fields for time series data associated with generators [`GeneratorTimeSeries`](@ref).
This allows features such as generation limits and ancillary service offers to be included in an optimisation problem, along with the variable prices defined by the generator offer curves.

The `SystemDA` type includes fields for additional supply (`increment`) and demand (`decrement`) bids for the purpose of modelling virtual participation in electricity markets ([introduction to virtual bidding](https://hepg.hks.harvard.edu/publications/virtual-bidding-and-electricity-market-design)).

Dictionaries mapping the generators, loads, and virtual bids to buses in the `System` are stored in fields `gens_per_bus`, `loads_per_bus` etc.

## Grid Matrices

This package also provides functions to calculate the Power Transfer Distribution Factor and Line Outage Distribution Factor matrices for a `System` of branches and buses.
These matrices are useful for modelling branch flow constraints under different contingency scenarios.
