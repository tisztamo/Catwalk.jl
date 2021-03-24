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

struct JIT
    id::Int
    callboosts::Vector{CallBoost}
    explorer::Explorer
end
function JIT(callboosts...; explorertype=BasicExplorer)
    id = rand(Int)
    opt = JIT(id, [], explorertype(id))
    for boost in callboosts
        add_boost!(opt, boost)
    end
    return opt
end

optimizerid(opt::JIT) = opt.id

function add_boost!(opt::JIT, boost)
    push!(opt.callboosts, boost)
    register_callsite!(opt.explorer, boost.fnsym)
end

function step!(opt::JIT)
    update_callboosts(opt)
    step!.(opt.callboosts)
    step!(opt.explorer)
end

function update_callboosts(opt::JIT)
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

function ctx(opt::JIT)
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
