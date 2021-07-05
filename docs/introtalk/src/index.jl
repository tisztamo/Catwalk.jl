# .title[Catwalk.jl: A profile guided dispatch optimizer]
#
# .log.blur[Krisztián Schäffer, independent researcher]
#
# .log.blur[JuliaCon 2021]
#
# ![](../../src/assets/catwalk-speeddemo.gif)
#
# ???
#
# Catwalk is an optimizing JIT compiler embedded in Julia. 
# It can speed up long-running processes by minimizing the overhead of dynamic dispatch.
#
# But wait, Julia itself is already a JIT compiler, isn't?
#
# ---
# ### Ahead Of Time compiler
# ![](aot.jpg)
#
# ???
# 
# A traditional compiler runs separately from the code it compiles, like
# when the machines lay the tracks first, and then execution, like a train,
# runs through the generated code.
#
# ---
# ### Julia: Just Ahead Of Time
# ![](jaot.jpg)
#
# ???
#
# Julia on the other hand can switch between execution and compilation.
# Code generation will be deferred to the latest possible point: Just before
# execution of that piece of code.
# The compiler has more information at that time, which it can use to
# optimize better.
#
# However, in Julia we typically only lay new tracks, and don't
# renew existing ones.
# Once a code was compiled, it is not really possible to recompile it, 
# meaning that information gathered during execution of the code cannot be used
# to re-optimize it.
#
# ---
# ### Optimizing Just In Time
# ![](jit.png)
#
# ???
#
# And this re-optimization during runtime is what Catwalk does for you.
# It profiles dynamic dispatch in your code, measuring the distribution of
# dispatched types, and generates fast, type-stable routes for the most frequent ones.
#
# ---
# ### A Rock-Paper-Scissors "simulation"

abstract type Hand end
struct Rock <: Hand end
struct Paper <: Hand end
struct Scissors <: Hand end

play(::T, ::T) where T = 3       # 3: Tie
play(::Paper, ::Rock) = 1        # 1: First player wins
play(::Scissors, ::Paper) = 1
play(::Rock, ::Scissors) = 1
play(a, b) = 3 - play(b, a) # Reverse order. 3-1 == 2: second player wins

play(Paper(), Scissors()) # Scissors cuts paper, second player wins

# .small.right[Example was inspired by https://giordano.github.io/blog/2017-11-03-rock-paper-scissors/]
#
# ???
#
# Let's see how it works.
# This is a classic example of the rock-paper-scissors game.
#
# Hands are modeled with types and game logic is implemented using multiple dispatch.
# The play function returns one if the first player wins, two if the second,
# and three on tie.
#
# --
#

const hands = [Rock(), Paper(), Scissors()] # Vector{Hand}

function playrand(hands)
    hand1 = rand(hands)
    hand2 = rand(hands)
    return play(hand1, hand2) # Dynamic dispatch
end
nothing # hide

#
# ???
#
# The `playrand` function simulates a single play of two random-strategy players.
# By the nature of our design the call to `play` is dynamically dispatched at run-time,
# because all we know is that both hand1 and hand2 are subtypes of the
# abstract type Hand.
#
# This dynamic dispatch implements our main logic, and it is where most of the runtime is spent.
# We will try to speed it up.

# ---
# ### Play repeatedly and count results

function playmatch(hands, num_plays, result)
    for i=1:num_plays
        winner = playrand(hands)::Int
        result[winner] += 1
    end
end

result = [0, 0, 0]
playmatch(hands, 1000, result)

result

# ???
#
# Let's say that the `playrand` function is called in a hot loop.
#
# Why? Well, if it is not called in a hot loop, then there is hardly a
# reason to speed it up.
#
# So a match is a sequence of plays between two players. We count
# the results in an array.

# ---
#
# ### all-play-all tournament of num_players

function tournament(hands, num_players)
    results = [[0,0,0] for i1=1:num_players, i2=1:num_players]
    for i1 = 1:num_players
        for i2 = i1+1:num_players
            playmatch(hands, 1000, results[i1, i2])
        end
    end
    return results
end

tournament(hands, 5)

#
# ???
#
# Going further, a tournament is a matrix of matches.
# All-play-all, one thousand-long matches.
#
# --
#
# Performance:

@time tournament(hands, 300)
nothing # hide

# ???
#
# It is not very slow with more than 10 million games per second, but it can be much faster.
#
# ---
#
# ### Speed it up!

# ##### Option 1: Redesign ...

# ##### Option 2: Union spliting (does not work here) ...

# ##### Option 3: Dispatch manually:

function playrand_manualdispatch(hands)
    hand1 = rand(hands)
    hand2 = rand(hands)
    if hand1 isa Rock
        return play(hand1, hand2) # Fast, (partially) type-stable route
    elseif hand1 isa Paper
        return play(hand1, hand2)
    elseif hand1 isa Scissors
        return play(hand1, hand2)
    end
    return play(hand1, hand2) # Fallback to fully dynamic dispatch
end
nothing # hide

# (ManualDispatch.jl may help, but not in this 2-args case)
#
# ???
#
# When we do not want to redesign, and union splitting fails to work,
# then the first real solution is manual dispatch.
# The code seems strange at first, because all the branches do the same
# thing. But if you ask: "What is the semantics of performance optimization?"
# The answer is that it must be a no-op. The optimized
# version is equivalent with the original. The difference between the branches is
# not semantics, only implementation. 
#
# The trick is that inside the branches the compiler knows the concrete type of hand1
# and will generate fast code based on this knowledge.
# You may have noticed that the type of hand2 is still unknown, so
# we still dispatch dynamically. But single dispatch is easier and the Julia compiler is very smart,
# it generates different code for the branches. Stabilizing `hand1` is enough for us now.
#
# The only problem with this solution is that we have to list the concrete types in the source code,
# which limits extensibility. If you want to introduce a new hand and still run fast,
# you have to change this code. That may not be feasible.
#
# So we arrive at Catwalk. It will automatically generate code that looks like this

# ---

using Catwalk

@jit play hand1 function playrand_jit(hands, jitctx)
    hand1 = rand(hands)
    hand2 = rand(hands)
    return play(hand1, hand2)
end

function playmatch_jit(hands, num_plays, result, jitctx)
    for i=1:num_plays
        winner = playrand_jit(hands, jitctx)::Int
        result[winner] += 1
    end
end

function tournament_jit(hands, num_players, jit=Catwalk.JIT())
    results = [[0,0,0] for i1=1:num_players, i2=1:num_players]
    for i1 = 1:num_players
        for i2 = i1+1:num_players
            Catwalk.step!(jit)
            playmatch_jit(hands, 1000, results[i1, i2], Catwalk.ctx(jit))
        end
    end
    return results
end
nothing # hide

# ???
#
# Let's see what we have to modify in our code.
# We mark `playrand` with the `@jit` macro and provide the name of the
# dynamically dispatched function, `play` and the argument to stabilize, `hand1`.
#
# Then we explicitly add the `jitctx` argument, which will drive the recompilation.
# When the Catwalk optimizer decides to compile a new version, it changes the type of
# the jit context, which triggers the recompilation. The type of the context
# describes the list of concrete types to stabilize.
# 
# The body of the function is the same. `playmatch` just forwards the jit context
# explicitly, while at the outer level we also have to do some housekeeping.
# Catwalk works in batches: it can recompile between batches, and it profiles
# batches separately. Here a batch is a single match.
# 
# ---
const jit = Catwalk.JIT()

@time tournament_jit(hands, 300, jit)
nothing # hide

# .log.blur[Debug: Found call site 'play', optimizing argument 'hand1'.]
# .log.blur[Debug: Profiled type freqs: Catwalk.Frequency[Catwalk.Frequency(Scissors, 334), Catwalk.Frequency(Paper, 330), Catwalk.Frequency(Rock, 336)\]]
# .log[Debug: Selected new fixtype list for 99.3% speedup vs last used, and 99.3% vs best: Rock, Scissors, Paper,]
# .log.blur[Debug: Profiled type freqs: Catwalk.Frequency[Catwalk.Frequency(Scissors, 364), Catwalk.Frequency(Paper, 324), Catwalk.Frequency(Rock, 312)\]]
# .log[Debug: Selected previous fixtype list: Rock, Scissors, Paper,]
# .log.blur[...]

#
# Hot start:

@time tournament_jit(hands, 300, jit)
nothing # hide

# ???
#
# And it is much faster now, we won around 50 percent. Of course, your mileage may vary.
# There is a huge initial compilation cost, so long-running processes
# will see higher wins.
#
# ---
# ### Reoptimization

function tournament_needing_reopt(hands, num_players, jit=Catwalk.JIT())
    results = [[0,0,0] for i1=1:num_players, i2=1:num_players]
    for i1 = 1:num_players
        hands = [Rock(), Paper(), (i1 > 20 ? Scissors() : Paper())] # No Scissors played by
        for i2 = i1+1:num_players                                   # the first 20 players
            Catwalk.step!(jit)
            playmatch_jit(hands, 1000, results[i1, i2], Catwalk.ctx(jit))
        end
    end
    return results
end
const reopt_jit = Catwalk.JIT()
@time tournament_needing_reopt(hands, 300, reopt_jit)
nothing # hide

# .log.blur[Debug: Profiled type freqs: Catwalk.Frequency[Catwalk.Frequency(Paper, 670), Catwalk.Frequency(Rock, 330)\]]
# .log[Debug: Selected new fixtype list for 99.4% speedup vs last used, and 99.4% vs best: **Paper, Rock,**]
# ...
# .log.blur[Debug: Profiled type freqs: Catwalk.Frequency[Catwalk.Frequency(Scissors, 298), Catwalk.Frequency(Paper, 351), Catwalk.Frequency(Rock, 351)\]]
# .log[Debug: Selected new fixtype list for 97.72% speedup vs last used, and 97.72% vs best: **Paper, Rock, Scissors,**]
#
# ???
#
# Catwalk was designed to handle situations where type distribution
# changes significantly during the run.
# This simple example shows it in action.
# The debug logs show that the first profile
# does not contain the Scissors type, but as it later appears, Catwalk recompiles.
# 
# ---
# ### Catwalk.jl highlights: 
#
#   - Low cost statistical profiler
#   - Tunable cost model
#   - Smart recompilation: Only if type-distribution changed significantly
#   - No world age issues, works inside a function
#   - 360 lines of readable vanilla Julia (no dependencies/ccall/llvmcall)
#
# Help, Tuning, inner workings, source of this example: https://tisztamo.github.io/Catwalk.jl/dev/
#

const configured_jit = Catwalk.JIT(;explorerfactory = Catwalk.NoExplorer)
Catwalk.add_boost!(
    configured_jit,
    Catwalk.CallBoost(
        :play,
        profilestrategy  =  Catwalk.SparseProfile(0.01),
        optimizer        =  Catwalk.TopNOptimizer(50;
                                compile_threshold = 1.04,
                                costmodel = Catwalk.DefaultDispatchCostModel(
                                    skip                = 4,
                                    static_dispatch     = 48,
                                    dynamic_dispatch    = 1000,
                                )
                            )
    ))

# .small.right[Configuration example]
#
# ???
#
# One more thing: We had no time to look inside, but there is no magic here.
# Even if you are a relative beginner to Julia, I suggest you to check the source
# code of Catwalk. It is simpler than you may think.
# But be warned: Metaprogramming is a rabbit hole!
#
# Thank you for your attention!
#

