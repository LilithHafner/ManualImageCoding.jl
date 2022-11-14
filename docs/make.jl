using ManualImageCoding
using Documenter

DocMeta.setdocmeta!(ManualImageCoding, :DocTestSetup, :(using ManualImageCoding); recursive=true)

makedocs(;
    modules=[ManualImageCoding],
    authors="Lilith Hafner <Lilith.Hafner@gmail.com> and contributors",
    repo="https://github.com/LilithHafner/ManualImageCoding.jl/blob/{commit}{path}#{line}",
    sitename="ManualImageCoding.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://LilithHafner.github.io/ManualImageCoding.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/LilithHafner/ManualImageCoding.jl",
    devbranch="main",
)
