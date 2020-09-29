module JIT

export compile, count_subtypes, @demo, createq

using GeneralizedGenerated
using BenchmarkTools

const NUM_TYPES = 2*10
const QUEUE_LENGTH = 100
@assert QUEUE_LENGTH >= NUM_TYPES

abstract type A{T} end
struct C1{T} <: A{T} end
struct C2{T} <: A{T} end

function createq(alpha=0.5, num_types = NUM_TYPES, queue_length = QUEUE_LENGTH )
    return [rand() < alpha ? C1{Val(i % num_types)}() : C2{Val(i % num_types)}() for i = 1:queue_length]
end

const c1_count = Ref(0)
const c2_count = Ref(0)
reset() = (c1_count[] = 0; c2_count[] =0)

count_subtypes(a::A) = nothing
count_subtypes(c1::C1) = (c1_count[] = c1_count[] + 1; nothing)
count_subtypes(c2::C2) = (c2_count[] = c2_count[] + 1; nothing)

function gg_compile(op, fixtype2)
    name = nameof(op)
    compiled_name = Symbol("_comp_$(nameof(op))")
    expr = quote
        (arg1::A) -> begin
            if arg1 isa $fixtype2
                return $name(arg1)
            end
            return $name(arg1)
        end
    end
    return runtime_eval(JIT, expr)
end


function compile(op, fixtype2)
    name = nameof(op)
    compiled_name = Symbol("_comp_$(nameof(op))")
    expr = quote
        @inline function $compiled_name(arg1::A)
            if arg1 isa $fixtype2
                return $name(arg1)
            end
            return $name(arg1)
        end
    end
    return eval(expr)
end

function demo(num_types=NUM_TYPES, queue_length = QUEUE_LENGTH)
    for alpha = 0.1:0.1:0.9
        println("\n" * string(alpha) *": Dynamic dispatch")
        reset()
        #@btime foreach(count_subtypes, q) setup=(q=createq($alpha, $num_types, $queue_length))

        fasttype = c1_count[] > c2_count[] ? C1 : C2
        #fasttype = rand() > 0.5 ? C2 : Int
        println("$alpha: $(c1_count[]) vs $(c2_count[]) => $fasttype")
        compiled=gg_compile(count_subtypes, fasttype)

        #compiled(C1{Int}())

        reset()
        @btime foreach(compiled, q) setup=(q=createq($alpha, $num_types, $queue_length))
    end
end

end # module
