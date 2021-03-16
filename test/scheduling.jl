# ---- Sample code simplified from the original use case of this jit optimizer (CircoCore.jl) ----

struct Addr
    box::UInt64
end
 
abstract type Actor{Tcore} end
 
struct Msg{TBody}
    target::Addr
    body::TBody
end
target(msg) = msg.target

abstract type AbstractScheduler{TMsg, TCoreState} end

mutable struct Scheduler{THooks, TMsg, TCoreState} <: AbstractScheduler{TMsg, TCoreState}
    msgqueue::Vector{Any}
    actorcache::Dict{UInt64,Any}
    hooks::THooks
    Scheduler{T}() where T = new{T,T,T}([], Dict())
end

@jit step_kern1! (msg) function step!(scheduler::AbstractScheduler, jitctx=JIT.OptimizerCtx())
    msg = popfirst!(scheduler.msgqueue)
    step_kern1!(msg, scheduler, jitctx)
    return nothing
end
 
@jit step_kern! (targetactor) function step_kern1!(msg, scheduler::AbstractScheduler, jitctx)
    targetbox = target(msg).box::UInt64
    targetactor = get(scheduler.actorcache, targetbox, nothing)
    step_kern!(scheduler, msg, targetactor)
end

@inline function step_kern!(scheduler::AbstractScheduler, msg, targetactor)
    onmessage(targetactor, msg.body, scheduler)
end

@inline function onmessage(actor, msg, scheduler)
    error("This should never happen.") # escape route for monkey-patching and co.
end

mutable struct PingPonger{TCore} <: Actor{TCore}
    addr::Addr
    core::TCore # boilerplate, should be eliminated by a dsl
end

struct Ping end
struct Pong end

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

function measure_steps(scheduler, ctx=JIT.OptimizerCtx(); num=1e6)
    startts = time_ns()
    for i=1:num
        step!(scheduler, ctx)
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
#step!(scheduler)

@testset "ping-pong" begin
    msgcallboost = CallBoost(:step_kern1!, profilestrategy = SparseProfile(0.02))
    actorcallboost = CallBoost(:step_kern!, profilestrategy = SparseProfile(0.02))
    optimizer = RuntimeOptimizer()
    #JIT.add_boost!(optimizer, msgcallboost)
    #JIT.add_boost!(optimizer, actorcallboost)
    #emptyoptimizer = RuntimeOptimizer()
    @show ctx(optimizer)
    normaltime = 0
    jittedtime = 0
    for i=1:40
        println("------ Next JIT round: -------")
        JIT.step!(optimizer)
        jittedtime += @time measure_steps(scheduler, ctx(optimizer))
        #@time measure_steps(scheduler, ctx(emptyoptimizer))
        normaltime += @time measure_steps(scheduler)
    end
    #@show emptyoptimizer
    win = 1.0 - (jittedtime / normaltime)
    println("jitted: $(jittedtime / 1e9), normal: $(normaltime / 1e9), win: $win")
    @show JIT.callsites
    @test win > 0.1
end
