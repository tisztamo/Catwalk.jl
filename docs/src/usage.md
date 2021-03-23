# Usage

Let's say you have a long-running calculation, organized into batches:

```julia
function runbatches()
    for batch = 1:1000
        hotloop(batch)
        # Log progress, etc.
    end
end
```

The hot loop calls the function `f(i)` which
itself calls the type-unstable function `get_some_x(i)` and 
passes the result of it to a calculation `calc_with_x`.

```julia
function hotloop(batch)
    for i = 1:1_000_000
        f(i + batch * 1_000_000)
    end
end

function f(i)
    x = get_some_x(i)
    calc_with_x(x)
end

const xs = Any[1, 2.0, ComplexF64(3.0, 3.0)]
get_some_x(i) = xs[i % length(xs) + 1]
calc_with_x(x) = x + 42
```

As `get_some_x` is not type-stable, `calc_with_x` must be dynamically
dispatched, which slows down the calculation:

```julia
julia> @code_warntype f(1)
Variables
  #self#::Core.Const(f)
  i::Int64
  x::Any

Body::Any
1 ─      (x = Main.get_some_x(i))
│   %2 = Main.calc_with_x(x)::Any
└──      return %2

julia> using BenchmarkTools

julia> @btime hotloop(batch) setup=(batch=rand(1:1000))
  22.224 ms (666666 allocations: 15.26 MiB)
```

Catwalk.jl provides the @jit macro that you can use to mark the call site
to speed up:

```julia
using Catwalk

@jit calc_with_x x function f_jit(i, jitctx) # We create a new function for comparison
    x = get_some_x(i)
    calc_with_x(x)
end
```

You have to provide the name of the dynamically dispatched function
and the argument to operate on to the macro (the API will hopefully
improve in the future). You also have to add an extra argument
named `jitctx` to the jit-ed function. So the jit-ed version of the hot loop is:

```julia
function hotloop_jit(jitctx)
    for i = 1:1_000_000
        f_jit(i, jitctx)
    end
end
```

The Catwalk optimizer will provide you the `jitctx` context which you have to pass
to the jit-ed function manually.
Also, every batch needs a bit more housekeeping to drive the Catwalk optimizer:

```julia
function runbatches_jit()
    opt = Catwalk.RuntimeOptimizer()
    for batch = 1:1000
        Catwalk.step!(opt)
        jitctx = Catwalk.ctx(opt)
        hotloop_jit(jitctx)
    end
end
```

Yes, it is a bit complicated to integrate your code with Catwalk, but it may
worth the effort:

```julia
julia> @time runbatches_jit()
 11.652952 seconds (668.95 M allocations: 15.037 GiB, 5.64% gc time, 8.13% compilation time)

julia> @time runbatches()
 23.684320 seconds (666.67 M allocations: 14.901 GiB, 2.66% gc time)
```

Please note that the speedup depends on the portion of the runtime spent in dynamic dispatch,
which is most likely smaller in your case than in this contrived example.