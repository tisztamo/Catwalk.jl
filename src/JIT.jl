"""
    JIT.jl

An optimizing Just In Time compiler written in Julia.
"""
module JIT

export @jit, RuntimeOptimizer, CallBoost, ctx, SparseProfile, CallCtx

include("typelist.jl")
include("frequencies.jl")
include("compile.jl")
include("profile.jl")
include("costmodel.jl")
include("optimize.jl")
include("explore.jl")

mutable struct CallBoost # TODO: worth parametrizing?
    fnsym::Symbol
    profilestrategy::ProfileStrategy
    optimizer::Optimizer
    profiler::Profiler
    round::Int
    CallBoost(fnsym; profilestrategy=SparseProfile(), optimizer=TopNOptimizer()) = new(fnsym, profilestrategy, optimizer, NoProfiler(), 1)
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

struct RuntimeOptimizer
    id::Int
    callboosts::Vector{CallBoost}
    explorer::Explorer
end
function RuntimeOptimizer(callboosts...; explorertype=BasicExplorer)
    id = rand(Int)
    opt = RuntimeOptimizer(id, [], explorertype(id))
    for boost in callboosts
        add_boost!(opt, boost)
    end
    return opt
end

optimizerid(opt::RuntimeOptimizer) = opt.id

function add_boost!(opt::RuntimeOptimizer, boost)
    push!(opt.callboosts, boost)
    register_callsite!(opt.id, boost.fnsym)
end

function step!(opt::RuntimeOptimizer)
    update_callboosts(opt)
    step!.(opt.callboosts)
    step!(opt.explorer)
end

function update_callboosts(opt::RuntimeOptimizer)
    currentsyms = Set(map(b -> b.fnsym, opt.callboosts))
    for newsite in setdiff(get_freshcallsites!(opt.id), currentsyms)
        add_boost!(opt, CallBoost(newsite))
    end
end

struct OptimizerCtx{TCallCtxs, TExplorer}
    callctxs::TCallCtxs
    explorer::TExplorer
    OptimizerCtx() = new{NamedTuple{}, NoExplorer}(NamedTuple(), NoExplorer())
    OptimizerCtx(optimizerid, callctxs, explorer) = new{typeof(callctxs), typeof(explorer)}(callctxs, explorer)
end

function ctx(opt::RuntimeOptimizer)
    callctxs = (;map(boost -> (boost.fnsym, ctx(boost)), opt.callboosts)...)
    return OptimizerCtx(optimizerid(opt), callctxs, opt.explorer)
end

function callctx(::Type{OptimizerCtx{TCallCtxs, TExplorer}}, key) where {TCallCtxs, TExplorer}
    return callctx(TCallCtxs, key)
end

function callctx(::Type{
            NamedTuple{TNames, TVals}
        }, key) where {TNames, TVals}
    name = nameof(key)
    idx = findfirst(n -> n==name, TNames)
    if isnothing(idx)
        #error("$key not found in $ctxs")
        return typeof(CallCtx())
    end
    return fieldtypes(TVals)[idx]
end

function callctx(::Type{NamedTuple}, key)
    return typeof(CallCtx()) # TODO eliminate?
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
