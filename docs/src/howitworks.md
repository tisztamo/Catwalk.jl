# How it works?

The `@jit` macro turns the outer function to a `@generated` one,
so that we can recompile with reoptimized source code at will.

The optimized code looks like this:

```julia
    x = get_some_x(i)
    if x isa FrequentType1
        calc_with_x(x) # Fast type-stable route
    elseif x isa FrequentType2
        calc_with_x(x) # Fast type-stable route
    .
    .
    .
    else
        calc_with_x(x) # Fallback to the dynamically dispatched call
    end
```

The *type* of the `jitctx` argument drives the compilation process, it
encodes everything needed to generate the code, namely the list of 
stabilized types and the type of the profiler that runs in the
current batch:

```julia
struct CallCtx{TProfiler, TFixtypes}
    profiler::TProfiler
end
```

Two profilers are implemented at the time:

```julia
struct NoProfiler <: Profiler end

struct FullProfiler <: Profiler
    typefreqs::DataTypeFrequencies
end
```

The `FullProfiler` collects statistics from every call.
It logs a call faster than a dynamic dispatch, but running
it in every batch would still eat a large part of the cake, so it
is sparsely used, with 1% probability by default (It is
always active during the first two batches). 

The last missing part is the explorer, which automatically
connects the JIT compiler with the `@jit`-ed functions that
run under its supervision.

Also, a single JIT compiler can handle multiple call sites,
so the `jitctx` in reality is not a single `CallCtx` as described
earlier, but a `NamedTuple` of them, plus an explorer:

```julia
struct OptimizerCtx{TCallCtxs, TExplorer}
    callctxs::TCallCtxs
    explorer::TExplorer
end
```

The explorer holds its id in its type, because exploration happens
during compilation, when only its type is available.

```julia
struct BasicExplorer{TOptimizerId} <: Explorer end
```

Here Catwalk - just like many other meta-heavy Julia packages -
violates the rule that a `@generated` function is not "allowed"
to access mutable global state. It logs the call site to a global
dict, keyed with its id, from where the JIT compiler can read it out.

It seems impossible to push back information from the compilation process
without breaking this rule, and pushing the exploration to the tight loop
we is not feasible.

The alternative is to configure the compiler with the call sites
and `NoExplorer` manually. TODO: link to tuning, when documented.
