using UnicodePlots

const STEPS_PER_ROUND=1e6

# ---- Sample code simplified from the original use case of this jit optimizer (CircoCore.jl) ----
#
# This is an actor scheduler, where the hot loop is parametrized with code,
# and the distribution of dispatched concrete types depends on the actor program
# that is executed.

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

@jit step_kern1! (msg) function step!(scheduler::AbstractScheduler, jitctx=Catwalk.OptimizerCtx())
    msg = popfirst!(scheduler.msgqueue) # get the next message
    step_kern1!(msg, scheduler, jitctx) # and deliver it (Catwalked call on message type)
    return nothing
end
 
# Kernel function to stabilize message type first. Gets the target actor and delivers the message
@inline @jit step_kern! (targetactor) function step_kern1!(msg, scheduler::AbstractScheduler, jitctx)
    targetbox = target(msg).box::UInt64
    targetactor = get(scheduler.actorcache, targetbox, nothing)
    step_kern!(scheduler, msg, targetactor) # Catwalked call on actor type
end

@inline function step_kern!(scheduler::AbstractScheduler, msg, targetactor)
    onmessage(targetactor, msg.body, scheduler)
end

@inline function onmessage(actor, msg, scheduler)
    error("This should never happen.") # escape route for monkey-patching and co.
end

# --- Non-jitted version for comparison

@inline function step_nojit!(scheduler::AbstractScheduler)
    msg = popfirst!(scheduler.msgqueue)
    step_kern1_nojit!(msg, scheduler)
    return nothing
end
 
@inline function step_kern1_nojit!(msg, scheduler::AbstractScheduler)
    targetbox = target(msg).box::UInt64
    targetactor = get(scheduler.actorcache, targetbox, nothing)
    step_kern!(scheduler, msg, targetactor)
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

function run_steps(scheduler, ctx=Catwalk.OptimizerCtx(); num=STEPS_PER_ROUND)
    for i=1:num
        step!(scheduler, ctx)
    end
end

function measure_steps(scheduler, opt; num=STEPS_PER_ROUND)
    startts = time_ns()
    Catwalk.step!(opt)
    run_steps(scheduler, Catwalk.ctx(opt))
    return time_ns() - startts
end

function measure_steps_nojit!(scheduler; num=STEPS_PER_ROUND)
    startts = time_ns()
    for i=1:num
        step_nojit!(scheduler)
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

@testset "ping-pong" begin
    msgcallboost = Catwalk.CallBoost(:step_kern1!, profilestrategy = Catwalk.SparseProfile(0.02))
    actorcallboost = Catwalk.CallBoost(:step_kern!, profilestrategy = Catwalk.SparseProfile(0.01))
    optimizer = JIT(;explorerfactory=Catwalk.NoExplorer)
    Catwalk.add_boost!(optimizer, msgcallboost)
    Catwalk.add_boost!(optimizer, actorcallboost)
    normaltime = 0
    jittedtime = 0
    for i=1:300
        println("------ Catwalk round #$(i): -------")
        jittedtime += measure_steps(scheduler, optimizer)
        normaltime += measure_steps_nojit!(scheduler)
        println(barplot(
            ["Catwalked", "original"],
            [jittedtime / 1e9, normaltime / 1e9];
            title="Runtime"
        ))
        win = 1.0 - (jittedtime / normaltime)
        winpercent = round(win * 100_000) / 1000
        println("Win: $(winpercent)%.")
        print(repeat("\n", 10))
        print(repeat("\u1b[1F", 10))
    end
    win = 1.0 - (jittedtime / normaltime)
    @test win > 0.1
end
