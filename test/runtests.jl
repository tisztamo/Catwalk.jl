using JIT
using Test
using BenchmarkTools

const NUM_TYPES = 20
const QUEUE_LENGTH = 100
@assert QUEUE_LENGTH >= NUM_TYPES

abstract type A{T} end
struct C1{T} <: A{T} end
struct C2{T} <: A{T} end

function createq(alpha=0.5, num_types = NUM_TYPES, queue_length = QUEUE_LENGTH )
    return A[rand() < alpha ? C1{Val(i % num_types)}() : C2{Val(i % num_types)}() for i = 1:queue_length]
end

const c1_count = Ref(0)
const c2_count = Ref(0)
reset() = (c1_count[] = 0; c2_count[] =0)

count_subtypes(a::A) = 0
count_subtypes(c1::C1) = (c1_count[] = c1_count[] + 1; 1)
count_subtypes(c2::C2) = (c2_count[] = c2_count[] + 1; 2)

oldcompiled = nothing

function demo_subtypes(num_types=NUM_TYPES, queue_length = QUEUE_LENGTH)
    compiled = nothing
    for alpha = 0.1:0.1:0.9
        print("\n" * string(alpha) *": Dynamic dispatch               ")
        reset()
        @btime foreach(count_subtypes, q) setup=(q=createq($alpha, $num_types, $queue_length))

        fasttype = c1_count[] > c2_count[] ? C1 : C2
        print("$alpha: $(c1_count[]) vs $(c2_count[]) => $fasttype")

        compiled = compile(count_subtypes; fixtypes=(fasttype,))

        @test compiled isa JIT.CompiledFn{typeof(count_subtypes)}
        @test compiled(C1{Int}()) == 1
        @test compiled(C2{Real}()) == 2

        reset()
        @btime foreach($compiled, q) setup=(q=createq($alpha, $num_types, $queue_length))
    end
end

@testset "demo_subtypes" begin
    demo_subtypes() # Also runs inside a function
end

@testset "fix and multifix" begin
    compiledC1 = compile(count_subtypes; fixtypes=(C1,))
    compiledC2 = compile(count_subtypes; fixtypes=(C2,))
    compiledBoth = compile(count_subtypes; fixtypes=(C1, C2))
    @test compiledC1(C1{Int}()) == 1
    @test compiledC2(C2{Real}()) == 2
    @test compiledC2(C1{Int}()) == 1
    @test compiledC2(C2{Real}()) == 2
    @test compiledBoth(C1{Int}()) == 1
    @test compiledBoth(C2{Real}()) == 2
    @show @btime foreach($compiledBoth, q) setup=(q=createq())
    @show @btime foreach($compiledC1, q) setup=(q=createq())
    @show @btime foreach($compiledC2, q) setup=(q=createq())
    @show @btime foreach($count_subtypes, q) setup=(q=createq())
end
