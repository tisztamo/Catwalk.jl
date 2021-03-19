using Logging

const DEFAULT_COMPILE_THRESHOLD = 1.04

abstract type Optimizer end

mutable struct TopNOptimizer <: Optimizer
    n::Int
    compile_threshold::Float32
    last_fixtypes
    fixtypes_history
    TopNOptimizer(n = 5, compile_threshold = DEFAULT_COMPILE_THRESHOLD) = new(n, compile_threshold, EmptyTypeList, [])
end

fixtypes(opt::TopNOptimizer, ::NoProfiler) = opt.last_fixtypes

struct Frequency
    type::Type
    freq::Int
end
Base.isless(a::Frequency, b::Frequency) = isless(a.freq, b.freq)

percent(x) = round((x) * 100) / 100

function fixtypes(opt::TopNOptimizer, prof::FullProfiler)
    ideal = ideal_fixtypes(opt, prof)
    idealcost = costof(typefreqs(prof), ideal)
    best_historic_cost = typemax(ClockCycle)
    best_idx = -1
    for idx in 1:length(opt.fixtypes_history)
        old = opt.fixtypes_history[idx]
        oldcost = costof(typefreqs(prof), old)
        if oldcost < best_historic_cost
            best_historic_cost = oldcost
            best_idx = idx
        end
    end
    if best_historic_cost > opt.compile_threshold * idealcost
        if Logging.min_enabled_level(current_logger()) >= Logging.Debug
            lastcost = costof(typefreqs(prof), opt.last_fixtypes)
            speedup_last = percent(1.0 - idealcost / lastcost)
            speedup_best = percent(1.0 - idealcost / best_historic_cost)
            @debug "Selected new fixtype list for $speedup_last speedup vs last used, and $speedup_best vs best: $ideal"
        end
        opt.last_fixtypes = ideal
        push!(opt.fixtypes_history, ideal)
    else
        @debug "Selected previous fixtype list: $ideal"
        opt.last_fixtypes = opt.fixtypes_history[best_idx]
    end
    return opt.last_fixtypes
end

function ideal_fixtypes(opt::TopNOptimizer, prof::FullProfiler)
    freqs = sort(map(p -> Frequency(p...), collect(pairs(typefreqs(prof)))); order=Base.Order.ReverseOrdering())
    topfreqs = freqs[1:min(opt.n, length(freqs))]
    return encode(map(f -> f.type, topfreqs)...)
end