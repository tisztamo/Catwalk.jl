"""
    JIT.jl

An optimizing Just In Time compiler written in Julia.
"""
module JIT

export @jit, RuntimeOptimizer, CallBoost, ctx, SparseProfile, CallCtx

include("typelist.jl")
include("compile.jl")
include("profile.jl")
include("optimize.jl")

mutable struct CallBoost # TODO: worth parametrizing?
    fnsym::Symbol
    profilestrategy::ProfileStrategy
    optimizer::Optimizer
    profiler::Profiler
    round::Int
    CallBoost(fnsym=:_auto; profilestrategy=SparseProfile(), optimizer=TopNOptimizer()) = new(fnsym, profilestrategy, optimizer, NoProfiler(), 0)
end

function step!(boost::CallBoost)
    boost.round += 1
end

function ctx(boost::CallBoost)
    newprofiler = getprofiler(boost.profilestrategy, boost.round)
    context = CallCtx{typeof(newprofiler), fixtypes(boost.optimizer, boost.profiler)}(newprofiler)
    empty!(newprofiler)
    boost.profiler = newprofiler
    return context
end

struct CallCtx{TProfiler, TFixtypes}
    profiler::TProfiler
    CallCtx() = new{NoProfiler, EmptyTypeList}()
    CallCtx{TProfiler, TFixtypes}(profiler) where {TProfiler, TFixtypes} = new{TProfiler, TFixtypes}(profiler)
end

fixtypes(::Type{CallCtx{TProfiler, TFixtypes}}) where {TProfiler, TFixtypes} = TFixtypes
profiler(ctx::CallCtx) = ctx.profiler

mutable struct RuntimeOptimizer
    callboosts::Vector{CallBoost}
    callsites::Set{Symbol}
    RuntimeOptimizer() = new([CallBoost()], Set())
    RuntimeOptimizer(callboosts...) = new([callboosts...], Set())
end

step!(opt::RuntimeOptimizer) = step!.(opt.callboosts)

struct OptimizerCtx{TCallCtxs}
    callctxs::TCallCtxs
    callsites::Set{Symbol}
    OptimizerCtx() = new{NamedTuple{}}(NamedTuple(), Set())
    OptimizerCtx(callctxs, callsites) = new{typeof(callctxs)}(callctxs, callsites)
end

function ctx(opt::RuntimeOptimizer)
    callctxs = (;map(boost -> (boost.fnsym, ctx(boost)), opt.callboosts)...)
    return OptimizerCtx(callctxs, opt.callsites)
end

function callctx(ctx::Type{OptimizerCtx{TCallCtxs}}, key) where TCallCtxs
    return callctx(TCallCtxs, key)
end

function callctx(ctxs::Type{NamedTuple{TNames, TVals}}, key) where {TNames, TVals}
    name = nameof(key)
    idx = findfirst(n -> n==name, TNames)
    if isnothing(idx)
        #error("$key not found in $ctxs")
        return typeof(CallCtx())
    end
    return fieldtypes(TVals)[idx]
end

function callctx(ctxs::Type{NamedTuple}, key)
    return typeof(CallCtx())
end

function log_callsite(ctx::OptimizerCtx, calledfn, argname)
    push!(ctx.callsites, nameof(calledfn))
end

end # module
