"""
    Catwalk.jl

An optimizing Just In Time compiler written in Julia.
"""
module Catwalk

export @jit, JIT

include("typelist.jl")
include("frequencies.jl")
include("compile.jl")
include("profile.jl")
include("costmodel.jl")
include("optimize.jl")
include("explore.jl")

mutable struct CallBoost
    fnsym::Symbol
    profilestrategy::ProfileStrategy
    optimizer::Optimizer
    currentprofiler::Profiler
    round::Int
    CallBoost(fnsym; profilestrategy=SparseProfile(), optimizer=TopNOptimizer()) = new(fnsym, profilestrategy, optimizer, NoProfiler(), 1)
end

function step!(boost::CallBoost)
    boost.round += 1
end

function ctx(boost::CallBoost)
    newprofiler = getprofiler(boost.profilestrategy, boost.round)
    context = CallCtx{typeof(newprofiler), fixtypes(boost.optimizer, boost.currentprofiler)}(newprofiler)
    empty!(newprofiler)
    boost.currentprofiler = newprofiler
    return context
end

struct CallCtx{TProfiler, TFixtypes}
    profiler::TProfiler
    CallCtx() = new{NoProfiler, EmptyTypeList}()
    CallCtx{TProfiler, TFixtypes}(profiler) where {TProfiler, TFixtypes} = new{TProfiler, TFixtypes}(profiler)
end

fixtypes(::Type{CallCtx{TProfiler, TFixtypes}}) where {TProfiler, TFixtypes} = TFixtypes
profiler(ctx::CallCtx) = ctx.profiler

struct JIT
    id::Int
    callboosts::Vector{CallBoost}
    explorer::Explorer
end
function JIT(callboosts...; explorerfactory=BasicExplorer)
    id = rand(Int)
    jit = JIT(id, [], explorerfactory(id))
    for boost in callboosts
        add_boost!(jit, boost)
    end
    return jit
end

optimizerid(jit::JIT) = jit.id

function add_boost!(jit::JIT, boost)
    push!(jit.callboosts, boost)
    register_callsite!(jit.explorer, boost.fnsym)
end

function step!(jit::JIT)
    update_callboosts(jit)
    step!.(jit.callboosts)
    step!(jit.explorer)
end

function update_callboosts(jit::JIT)
    currentsyms = Set(map(b -> b.fnsym, jit.callboosts))
    for newsite in setdiff(get_freshcallsites!(jit.id), currentsyms)
        add_boost!(jit, CallBoost(newsite))
    end
end

struct OptimizerCtx{TCallCtxs, TExplorer}
    callctxs::TCallCtxs
    explorer::TExplorer
    OptimizerCtx() = new{NamedTuple{}, NoExplorer}(NamedTuple(), NoExplorer())
    OptimizerCtx(optimizerid, callctxs, explorer) = new{typeof(callctxs), typeof(explorer)}(callctxs, explorer)
end

function ctx(jit::JIT)
    callctxs = (;map(boost -> (boost.fnsym, ctx(boost)), jit.callboosts)...)
    return OptimizerCtx(optimizerid(jit), callctxs, jit.explorer)
end

function callctx(::Type{OptimizerCtx{TCallCtxs, TExplorer}}, key) where {TCallCtxs, TExplorer}
    return callctx(TCallCtxs, key)
end

function callctx(::Type{NamedTuple{TNames, TVals}}, key) where {TNames, TVals}
    name = nameof(key)
    idx = findfirst(n -> n == name, TNames)
    if isnothing(idx)
        error("$key not found in $ctxs")
    end
    return fieldtypes(TVals)[idx]
end

function explorer(::Type{
        OptimizerCtx{
            TCallCtxs,
            TExplorer
        }
    }) where {TCallCtxs, TExplorer}
    return TExplorer
end

end # module
