abstract type Optimizer end

mutable struct TopNOptimizer{N} <: Optimizer
    last_fixtypes::Union{EmptyTypeList, TypeListItem}
    TopNOptimizer(n=5) = new{n}(EmptyTypeList())
end

fixtypes(opt::TopNOptimizer, ::NoProfiler) = typeof(opt.last_fixtypes)

struct Frequency
    type::Type
    freq::Int
end
Base.isless(a::Frequency, b::Frequency) = isless(a.freq, b.freq)

function fixtypes(opt::TopNOptimizer{N}, prof::FullProfiler) where N
    freqs = sort(map(p -> Frequency(p...), collect(pairs(typefreqs(prof)))); order=Base.Order.ReverseOrdering())
    topfreqs = freqs[1:min(N,length(freqs))]
    opt.last_fixtypes = encode(map(f -> f.type, topfreqs)...)()
    return typeof(opt.last_fixtypes)
end