# push!(LOAD_PATH, "../src/")
using MetaQNL
using Documenter

DocMeta.setdocmeta!(MetaQNL, :DocTestSetup, :(using MetaQNL); recursive = true)
doctest(MetaQNL)
makedocs(
    sitename = "MetaQNL.jl",
    format = Documenter.HTML(prettyurls = get(ENV, "CI", nothing) == "true"),
)
#=
Uncomment when the repo becomes public
deploydocs(
    repo = "github.com/princeton-vl/MetaQNL.jl.git",
    devbranch="main",
)
=#
