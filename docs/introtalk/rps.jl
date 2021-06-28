
# Rock-Paper-Scissors example, inspired by https://giordano.github.io/blog/2017-11-03-rock-paper-scissors/

# We model player moves with types
abstract type Hand end
struct Rock <: Hand end
struct Paper <: Hand end
struct Scissors <: Hand end

play(::T, ::T) where T = 3       # 3: Tie
play(::Paper, ::Rock) = 1        # 1: First player wins
play(::Scissors, ::Paper) = 1
play(::Rock, ::Scissors) = 1
play(a, b) = 3 - play(b, a) # Reverse order. 3-1==2: second player wins

# Example
play(Paper, Scissors)


function playrand(hands)
    hand1 = rand(hands)
    hand2 = rand(hands)
    return play(hand1, hand2)
end

function playmatch(hands, num_plays, result)
    for i=1:num_plays
        winner = playrand(hands)::Int # The compiler cannot infer the return type
        result[winner] += 1
    end
end

function tournament(hands, num_players)
    results = [[0,0,0] for i1=1:num_players, i2=1:num_players]
    for i1 = 1:num_players
        for i2 = i1+1:num_players
            playmatch(hands, 10_000, results[i1, i2])
        end
        print(".")
    end
    return results
end

hands = [Rock(), Paper(), Scissors()]

# JIT

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

function tournament_jit(hands, num_players)
    results = [[0,0,0] for i1=1:num_players, i2=1:num_players]
    jit = Catwalk.JIT()
    for i1 = 1:num_players
        for i2 = i1+1:num_players
            Catwalk.step!(jit)
            playmatch_jit(hands, 10_000, results[i1, i2], Catwalk.ctx(jit))
        end
        print(".")
    end
    return results
end

            # hands = [
            #    [repeat([Rock()], i1)..., Paper(), Paper(), Paper(), (i1 > 20 ? Scissors() : Paper())],
            #    [Rock(), Paper(), Scissors()],
            # ]
