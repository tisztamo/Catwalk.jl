using Logging

const DEFAULT_COMPILE_THRESHOLD = 1.04

abstract type Optimizer end

mutable struct TopNOptimizer{TCostModel} <: Optimizer
    n::Int
    compile_threshold::Float32
    costmodel::TCostModel
    last_fixtypes
    fixtypes_history
    TopNOptimizer(
        n = 10;
        compile_threshold = DEFAULT_COMPILE_THRESHOLD,
        costmodel = basemodel) = new{typeof(costmodel)}(n, compile_threshold, costmodel, EmptyTypeList, [])
end

fixtypes(opt::TopNOptimizer, ::NoProfiler) = opt.last_fixtypes

percent(x) = round((x) * 10_000) / 100

function find_best_historic_cost(opt, _typefreqs, costmodel)
    best_historic_cost = typemax(ClockCycle)
    best_idx = -1
    for idx in 1:length(opt.fixtypes_history) # TODO Do not calculate for all if the list is lengthy
        old = opt.fixtypes_history[idx]
        oldcost = costof(_typefreqs, old, costmodel)
        if oldcost < best_historic_cost
            best_historic_cost = oldcost
            best_idx = idx
        end
    end
    return best_idx, best_historic_cost
end

function fixtypes(opt::TopNOptimizer, prof::FullProfiler)
    tfs = typefreqs(prof)
    @debug "Profiled type freqs: $(tfs)"
    ideal = ideal_fixtypes(opt, prof)
    idealcost = costof(tfs, ideal, opt.costmodel)
    best_idx, best_historic_cost = find_best_historic_cost(opt, tfs, opt.costmodel)
    if best_historic_cost > opt.compile_threshold * idealcost
        @debug begin
            lastcost = costof(typefreqs(prof), opt.last_fixtypes, opt.costmodel)
            speedup_last = percent(1.0 - idealcost / lastcost)
            speedup_best = percent(1.0 - idealcost / best_historic_cost)
            "Selected new fixtype list for $(speedup_last)% speedup vs last used, and $(speedup_best)% vs best: $ideal"
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
    freqs = sort(collect(typefreqs(prof)); order=Base.Order.ReverseOrdering())
    topfreqs = freqs[1:min(opt.n, length(freqs))]
    return encode(map(f -> f.type, topfreqs)...)
end