# How it works?

## Generated code

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

## Iterated staging

Catwalk.jl uses a technique I call *"iterated staging"*, which is
essentially an outer loop which repetitively recompiles parts of
the loop body.

Recompilation happens by encoding the current *"stage"* - the
list of concrete types to speed up and the profiler config - into a type and
passing an instance of that type, called the *"JIT context"* to the inner
function in the loop body.

Only the *type* of the JIT context drives the compilation process, as
it is the only data available to the `@generated` inner function.

## JIT context basics

This is how the context looks like:

```julia
struct CallCtx{TProfiler, TFixtypes}
    profiler::TProfiler
end
```

Where `TFixTypes` encodes everything needed to generate the
dispatch code, and `TProfiler` describes the profiler configuration
used in the current batch.

`TFixTypes` is built with recursive type parameters
that encode the stabilized types as a linked list.
For example, to speed up `FrequentType1` and `FrequentType2`, the
optimizer generates a concrete type by recursively parametrizing
the `TypeListItem` generic type:

```julia
struct TypeListItem{TThis, TNext} end
struct EmptyTypeList end

julia> Catwalk.encode(FrequentType1, FrequentType2)

Catwalk.TypeListItem{FrequentType1, Catwalk.TypeListItem{FrequentType2, Catwalk.EmptyTypeList}}
```

Passing this "type list" as part of the JIT context allows the `@generated`
function to generate the type-stable routes.

## Profilers

The other part of the context is the profiler.
Two profilers are implemented at the time:

```julia
struct NoProfiler <: Profiler end

struct FullProfiler <: Profiler
    typefreqs::DataTypeFrequencies
end
```

The `FullProfiler` collects statistics from every call.
It logs a call faster than a dynamic dispatch, but running
it in every batch would still eat most of the cake, so it
is sparsely used, with 1% probability by default (It is
always active during the first two batches). 

## Explorer and the full JIT context

The last missing part is the explorer, which automatically
connects the JIT compiler with the `@jit`-ed functions that
run under its supervision.

This connection is not trivial because the `@jit` macro is only
applied to a single function which is somewhere "inside" the
batch, potentially in another package than the outer loop.
It is possible to configure the optimizer manually, but
the Explorer can automatically find the `@jit`-ed call sites
that are called in the batch.

As a single JIT compiler can handle multiple call sites,
the `jitctx` in reality is not a single `CallCtx` as described
earlier, but a `NamedTuple` of them, plus an explorer:

```julia
struct OptimizerCtx{TCallCtxs, TExplorer}
    callctxs::TCallCtxs # NamedTuple of `CallCtx`s
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
to access mutable global state. The explorer logs the call site to
a global dict, keyed with its id, from where the JIT compiler
can read it out during the next batch.

It seems impossible to send back information from the compilation process
without breaking this rule, and pushing the exploration to the tight loop
is not feasible.

I think that this violation is acceptible
(note that `RuntimeGeneratedFunctions` also does the same), but it is possible
to turn off the Explorer, as described in the tuning guide.
