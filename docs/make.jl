using Documenter, Catwalk

makedocs(
    modules = [Catwalk],
    format = Documenter.HTML(; prettyurls = get(ENV, "CI", nothing) == "true"),
    authors = "Krisztián Schäffer",
    sitename = "Catwalk.jl",
    pages = Any["index.md", "usage.md"]
    # strict = true,
    # clean = true,
    # checkdocs = :exports,
)

deploydocs(
    repo = "github.com/tisztamo/Catwalk.jl.git",
    push_preview = true,
    devbranch = "main",
)
