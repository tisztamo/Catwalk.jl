# ```@meta
# EditURL = "https://github.com/tisztamo/Catwalk.jl/blob/main/docs/src/usage.jl"
# ```
# # Usage

# Let's say you have a long-running calculation, organized into batches:

const NUM_BATCHES = 1000

function runbatches()
    for batchidx = 1:NUM_BATCHES
        hotloop()
        ## Log progress, etc.
    end
end

# The hot loop calls the type-unstable function `get_some_x()` and 
# passes its result to a relatively cheap calculation `calc_with_x()`.

const NUM_ITERS_PER_BATCH = 1_000_000

function hotloop()
    for i = 1:NUM_ITERS_PER_BATCH
        x = get_some_x(i)
        calc_with_x(x)
    end
end

const xs = Any[1, 2.0, ComplexF64(3.0, 3.0)]
get_some_x(i) = xs[i % length(xs) + 1]

const result = Ref(ComplexF64(0.0, 0.0))

function calc_with_x(x)
    result[] += x
end

# As `get_some_x` is not type-stable, `calc_with_x` must be dynamically
# dispatched, which slows down the calculation.
#
# Sometimes it is not feasible to type-stabilize `get_some_x`.
# Catwalk.jl is here for those cases.
# 
# You mark `hotloop`, the outer function
# with the `@jit` macro and provide the name of the dynamically
# dispatched function
# and the argument to operate on (the API will hopefully
# improve in the future). You also have to add an extra argument
# named `jitctx` to the jit-ed function:

using Catwalk

@jit calc_with_x x function hotloop_jit(jitctx)
    for i = 1:NUM_ITERS_PER_BATCH
        x = get_some_x(i)
        calc_with_x(x)
    end
end

# The Catwalk optimizer will provide you the `jitctx` context which you have to pass
# to the jit-ed function manually.
# Also, every batch needs a bit housekeeping to drive the Catwalk optimizer:

function runbatches_jit()
    jit = Catwalk.JIT() ## Also works inside a function (no eval used)
    for batch = 1:NUM_BATCHES
        Catwalk.step!(jit)
        hotloop_jit(Catwalk.ctx(jit))
    end
end

# Yes, it is a bit complicated to integrate your code with Catwalk, but it may
# worth the effort:

result[] = ComplexF64(0, 0)
@time runbatches_jit()

## 4.608471 seconds (4.60 M allocations: 218.950 MiB, 0.56% gc time, 21.68% compilation time)

jit_result = result[]

result[] = ComplexF64(0, 0)
@time runbatches()

## 23.387341 seconds (1000.00 M allocations: 29.802 GiB, 7.71% gc time)

# And the results are the same:

jit_result == result[] || error("JIT must be a no-op!")

# Please note that the speedup depends on the portion of the runtime spent in dynamic dispatch,
# which is most likely smaller in your case than in this contrived example.
#
# You can find this example under [docs/src/usage.jl](https://github.com/tisztamo/Catwalk.jl/blob/main/docs/src/usage.jl) in the repo.
