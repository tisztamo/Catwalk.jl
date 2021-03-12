"""
    JIT.jl

An optimizing Just In Time compiler written in Julia.
"""
module JIT

export @jit, CallBoost, ctx, SparseProfile, JITContext

include("typelist.jl")
include("compile.jl")
include("profile.jl")
include("optimize.jl")

mutable struct CallBoost # TODO: worth parametrizing?
    profilestrategy::ProfileStrategy
    optimizer::Optimizer
    profiler::Profiler
    round::Int
    CallBoost(strategy, optimizer=TopNOptimizer()) = new(strategy, optimizer, NoProfiler(), 0)
end

function step!(boost::CallBoost)
    boost.round += 1
end

function ctx(boost::CallBoost)
    newprofiler = getprofiler(boost.profilestrategy, boost.round)
    context = JITContext{typeof(newprofiler), fixtypes(boost.optimizer, boost.profiler)}(newprofiler)
    empty!(newprofiler)
    boost.profiler = newprofiler
    return context
end

struct JITContext{TProfiler, TFixtypes}
    profiler::TProfiler
    JITContext() = new{NoProfiler, EmptyTypeList}()
    JITContext{TProfiler, TFixtypes}(profiler) where {TProfiler, TFixtypes} = new{TProfiler, TFixtypes}(profiler)
end

fixtypes(::Type{JITContext{TProfiler, TFixtypes}}) where {TProfiler, TFixtypes} = TFixtypes
profiler(ctx::JITContext) = ctx.profiler

end # module
