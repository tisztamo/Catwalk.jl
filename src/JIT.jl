module JIT

export compile, compile, count_subtypes, @demo, createq

using BenchmarkTools

const NUM_TYPES = 20
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

count_subtypes(a::A) = 0
count_subtypes(c1::C1) = (c1_count[] = c1_count[] + 1; 1)
count_subtypes(c2::C2) = (c2_count[] = c2_count[] + 1; 2)

struct JITFn{TOp, TFixType, TNext}
    op::TOp
    next::TNext
end

compile(op) = JITFn{typeof(op), Nothing, Nothing}(op, nothing)
compile(op, fixtype) = JITFn{typeof(op), fixtype, Nothing}(op, nothing)
compile(op, fixtype, fixtypes...) = begin
    next = compile(op, fixtypes)
    return JITFn{typeof(op), fixtype, typeof(next)}(op, next)
end

@inline (j::JITFn{TOp, TFixType, TNext})(arg) where {TOp, TFixType, TNext} = begin
    if arg isa TFixType
        return j.op(arg)
    end
    if TNext === Nothing
        return j.op(arg)
    end
    return TNext(arg)
end

function demo(num_types=NUM_TYPES, queue_length = QUEUE_LENGTH)
    for alpha = 0.1:0.1:0.9
        print("\n" * string(alpha) *": Dynamic dispatch               ")
        reset()
        @btime foreach(count_subtypes, q) setup=(q=createq($alpha, $num_types, $queue_length))

        fasttype = c1_count[] > c2_count[] ? C1 : C2
        print("$alpha: $(c1_count[]) vs $(c2_count[]) => $fasttype")
        compiled = compile(count_subtypes, fasttype)

        #@test compiled(C1{Int}()) == 1
        #@test compiled(C2{Real}()) == 2

        reset()
        @btime foreach($compiled, q) setup=(q=createq($alpha, $num_types, $queue_length))
    end
end

end # module
