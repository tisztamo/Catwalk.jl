using Documenter, Catwalk, Literate

Literate.markdown("docs/src/usage.jl", "docs/src"; documenter=false, execute=false)

makedocs(
    modules = [Catwalk],
    format = Documenter.HTML(; prettyurls = get(ENV, "CI", nothing) == "true"),
    authors = "Krisztián Schäffer",
    sitename = "Catwalk.jl",
    pages = Any["index.md", "usage.md", "howitworks.md", "tuning.md"],
    # strict = true,
    # clean = true,
    # checkdocs = :exports,
)

deploydocs(
    repo = "github.com/tisztamo/Catwalk.jl.git",
    push_preview = true,
    devbranch = "main",
)
