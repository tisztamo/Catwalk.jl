using Documenter, JIT

makedocs(
    modules = [JIT],
    format = Documenter.HTML(; prettyurls = get(ENV, "CI", nothing) == "true"),
    authors = "Schaffer Krisztian",
    sitename = "JIT.jl",
    pages = Any["index.md"]
    # strict = true,
    # clean = true,
    # checkdocs = :exports,
)

deploydocs(
    repo = "github.com/tisztamo/JIT.jl.git",
    push_preview = true
)
