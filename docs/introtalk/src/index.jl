# ## Catwalk.jl 8-min intro
# Krisztián Schäffer, JuliaCon 2021

# Performance-optimization of a Rock-Paper-Scissors "simulation".

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

# (Example was inspired by https://giordano.github.io/blog/2017-11-03-rock-paper-scissors/)

# ---
# A single play by two random players:

function playrand(hands)
    hand1 = rand(hands)
    hand2 = rand(hands)
    return play(hand1, hand2)
end
nothing # hide

# Type instability causes dynamic (run-time) dispatch:

const hands = [Rock(), Paper(), Scissors()]

using InteractiveUtils # hide
@code_warntype playrand(hands)

# ---
# Play repeatedly and count results:

function playmatch(hands, num_plays, result)
    for i=1:num_plays
        winner = playrand(hands)::Int
        result[winner] += 1
    end
end

result = [0, 0, 0]
playmatch(hands, 10_000, result)

result

# ---
# all-play-all tournament of num_players:

function tournament(hands, num_players)
    results = [[0,0,0] for i1=1:num_players, i2=1:num_players]
    for i1 = 1:num_players
        for i2 = i1+1:num_players
            playmatch(hands, 10_000, results[i1, i2])
        end
    end
    return results
end

tournament(hands, 5)

# ---
# Performance:

@time tournament(hands, 100)
nothing # hide

# Speed it up!

# ##### Option 1: Redesign ...

# ##### Option 2: Union spliting ...

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

# ---
# ##### Option 4: JIT with Catwalk:

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
        Catwalk.step!(jit)
        jitctx = Catwalk.ctx(jit)
        for i2 = i1+1:num_players
            playmatch_jit(hands, 10_000, results[i1, i2], jitctx)
        end
    end
    return results
end
nothing # hide

# ---
const jit = Catwalk.JIT()

@time tournament_jit(hands, 100, jit)
nothing # hide

# Hot start:

@time tournament_jit(hands, 100, jit)
nothing # hide

# ---
# ### Catwalk.jl highlights: 
#
#   - Low cost statistical profiler
#   - Tunable cost model
#   - Smart recompilation: Only if type-distribution changed significantly
#   - No world age issues, works inside a function
#   - 360 lines of readable vanilla Julia (no dependencies/ccall/llvmcall)
#
# Sample source: https://github.com/tisztamo/Catwalk.jl/tree/main/docs/introtalk
#
# Help, Tuning, inner workings: https://tisztamo.github.io/Catwalk.jl/dev/
#

typeof(Catwalk.ctx(jit))

# hands = [
#    [repeat([Rock()], i1)..., Paper(), Paper(), Paper(), (i1 > 20 ? Scissors() : Paper())],
#    [Rock(), Paper(), Scissors()],
# ]
