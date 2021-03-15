using Random

rng = MersenneTwister(42)

abstract type Profiler end

Base.empty!(p::Profiler) = nothing
log_dispatch(p::Profiler, fn, type) = nothing
typefreqs(p::Profiler) = p.typefreqs

function profileexpr(calledfn, argname)
    return quote
        JIT.log_dispatch(JIT.profiler(jitctx.callctxs.$calledfn), $(calledfn), typeof($argname))
    end
end

struct NoProfiler <: Profiler end

struct FullProfiler <: Profiler
    typefreqs::IdDict{Type, Int}
    FullProfiler() = new(IdDict())
end

Base.empty!(p::FullProfiler) = empty!(p.typefreqs)

@inline function log_dispatch(p::FullProfiler, fn, type)
    old = get(p.typefreqs, type, 0)
    p.typefreqs[type] = old + 1 
end

abstract type ProfileStrategy end
struct SparseProfile <: ProfileStrategy
    sparsity::Float16
    profiler::FullProfiler
    SparseProfile(sparsity = 0.01) = new(sparsity, FullProfiler())
end

function getprofiler(strategy::SparseProfile, round::Integer)
    if round <= 1 || rand(rng) <= strategy.sparsity
        return strategy.profiler
    end
    return NoProfiler()
end
