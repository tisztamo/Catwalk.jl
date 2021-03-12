using JIT
using Test
using BenchmarkTools

@testset "Encode-decode" begin
    @test JIT.encode(Int)() isa JIT.TypeListItem
    for typelist in [
        (Int,),
        (Int, Float16),
        (Dict{Any,Any},),
        (Dict{Any,Any}, Int, Integer),
        ()
    ]
        @test JIT.decode(JIT.encode(typelist...)) == typelist
    end
end

# ---- Sample code extracted from the original target of this package (CircoCore.jl) ----

struct Addr
    box::UInt64
end
 
abstract type Actor{Tcore} end

mutable struct PingPonger{TCore} <: Actor{TCore}
    addr::Addr
    core::TCore
end
 
struct Msg{TBody}
    target::Addr
    body::TBody
end
target(msg) = msg.target

struct Ping end
struct Pong end

abstract type AbstractScheduler{TMsg, TCoreState} end
mutable struct Scheduler{THooks, TMsg, TCoreState} <: AbstractScheduler{TMsg, TCoreState}
    msgqueue::Vector{Any}
    actorcache::Dict{UInt64,Any}
    hooks::THooks
    Scheduler{T}() where T = new{T,T,T}([], Dict())
end

@inline @jit step_kern1! msg function step!(scheduler::AbstractScheduler, jitctx=JITContext(), fixactors=JITContext())
    msg = popfirst!(scheduler.msgqueue)
    step_kern1!(msg, scheduler,fixactors)
    return nothing
end
 
@inline @jit step_kern! targetactor function step_kern1!(msg, scheduler::AbstractScheduler, jitctx)
    targetbox = target(msg).box::UInt64
    targetactor = get(scheduler.actorcache, targetbox, nothing)
    step_kern!(scheduler, msg, targetactor)
end

@inline function step_kern!(scheduler::AbstractScheduler, msg, targetactor)
    onmessage(targetactor, msg.body, scheduler)
end

@inline function onmessage(actor, msg, scheduler)
    error(42)
end

for i=1:10
    name = Symbol(string("Body", i))
    eval(:(struct $name end))
    eval(quote
        @inline function onmessage(actor, msg::$(name), scheduler)
            print($name)
        end            
    end)
end

@inline function onmessage(actor, msg::Pong, scheduler)
    push!(scheduler.msgqueue, Msg{Ping}(actor.addr, Ping()))
end

@inline function onmessage(actor, msg::Ping, scheduler)
    push!(scheduler.msgqueue, Msg{Pong}(actor.addr, Pong()))
end

function measure_steps(scheduler, fixtypes=JITContext(), fixactors=JITContext(); num=1e6)
    startts = time_ns()
    for i=1:num
        step!(scheduler, fixtypes, fixactors)
    end
    return time_ns() - startts
end

const scheduler = Scheduler{Set}()
scheduler.actorcache[42] = PingPonger{Dict}(Addr(42), Dict())
for i=1:10
    body = eval(:($(Symbol(string("Body", i)))))
    push!(scheduler.msgqueue, Msg{body}(Addr(42), body()))
end
push!(scheduler.msgqueue, Msg{Ping}(Addr(42), Ping()))
step!(scheduler)

@testset "ping-pong" begin
    msgcallboost = CallBoost(SparseProfile(0.02))
    actorcallboost = CallBoost(SparseProfile(0.02))
    normaltime = 0
    jittedtime = 0
    for i=1:100
        println("------ Next JIT round: -------")
        JIT.step!(msgcallboost)
        JIT.step!(actorcallboost)
        jittedtime += @time measure_steps(scheduler, ctx(msgcallboost), ctx(actorcallboost))
        normaltime += @time measure_steps(scheduler)
    end
    win = 1.0 - (jittedtime / normaltime)
    println("jitted: $(jittedtime / 1e9), normal: $(normaltime / 1e9), win: $win")
    @test win > 0.2
end