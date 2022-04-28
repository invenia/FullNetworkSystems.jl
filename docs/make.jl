using AxisKeys: KeyedArray
using FullNetworkSystems
using InlineStrings: String15, String31
using Documenter

DocMeta.setdocmeta!(FullNetworkSystems, :DocTestSetup, :(using FullNetworkSystems); recursive=true)

makedocs(;
    modules=[FullNetworkSystems],
    authors="Invenia Technical Computing Corporation",
    repo="https://github.com/invenia/FullNetworkSystems.jl/blob/{commit}{path}#{line}",
    sitename="FullNetworkSystems.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://invenia.github.io/FullNetworkSystems.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
    checkdocs=:exports,
    strict=true,
)

deploydocs(;
    repo="github.com/invenia/FullNetworkSystems.jl",
    devbranch="main",
)
