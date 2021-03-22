using Documenter, JIT

makedocs(
    modules = [JIT],
    format = Documenter.HTML(; prettyurls = get(ENV, "CI", nothing) == "true"),
    authors = "Krisztián Schäffer",
    sitename = "JIT.jl",
    pages = Any["index.md", "usage.md"]
    # strict = true,
    # clean = true,
    # checkdocs = :exports,
)

deploydocs(
    repo = "github.com/tisztamo/JIT.jl.git",
    push_preview = true
)
