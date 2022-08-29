using AxisKeys
using DataFrames
using Dates
using Dictionaries
using FullNetworkSystems
using Random: randstring
using SparseArrays
using Test

@testset "FullNetworkSystems.jl" begin
    include("system.jl")
    include("block_inv.jl")
    include("matrices.jl")
end
