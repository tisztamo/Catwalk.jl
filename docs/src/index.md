# Catwalk.jl Intro

Catwalk.jl can speed up long-running Julia processes by minimizing the
overhead of dynamic dispatch. It is a JIT compiler that continuosly
re-optimizes dispatch code based on data collected at runtime.

![Speedup demo](assets/catwalk-speeddemo.gif)
[source code of this test](https://github.com/tisztamo/Catwalk.jl/blob/main/test/scheduling.jl)

It profiles user-specified call sites, estimating the distribution of
dynamically dispatched types during runtime, and generates fast
static routes for the most frequent ones on the fly.

The statistical profiler has very low overhead and can be configured
to handle situations where the distribution of dispatched types
changes relatively fast.

To minimize compilation overhead, recompilation only occurs when the
distribution changed enough and the tunable cost model predicts
significant speedup compared to the best version that was previously
compiled.

## When to use this package

Catwalk.jl focuses on use cases when it is not feasible to list the dynamically dispatched concrete types in the source code of the call site, and when the calculation is relatively complex or composed from different codebases. For simpler use cases, or when compilation
overhead should be minimal, you may find better alternatives (See the list below).

Catwalk.jl assumes the followings:

- The process is long running: several seconds, but possibly minutes are needed to break even after the initial compilation overhead.
- Few dynamically dispatched call sites contribute significantly to the running time (dynamic dispatch in a hot loop).
- You can modify the source code around the interesting call sites (add a macro call), and calculation is organized into batches.

## Alternatives

- [SingleDispatchArrays.jl](https://github.com/melonedo/SingleDispatchArrays.jl) gives you fast single dispatch for arrays of non-homogeneous elements.
- JuliaFolds packages in general try to do a weaker version of this, as discussed in: [Tail-call optimization and function-barrier -based accumulation in loops](https://discourse.julialang.org/t/tail-call-optimization-and-function-barrier-based-accumulation-in-loops/25831).
- [ManualDispatch.jl](https://github.com/jlapeyre/ManualDispatch.jl) can serve you better in less dynamic cases, when it is feasible to list the dynamically dispatched types in the source code.
- In even simpler cases using unions instead of a type hierarchy may allow the Julia compiler to "split the union". See for example [List performance improvent by Union-typed tail](https://github.com/JuliaCollections/DataStructures.jl/pull/682/commits/4742228d42ae441f9837e5825feedeb1c013bd99) in DataStructures.jl.
- [FunctionWrappers.jl](https://github.com/yuyichao/FunctionWrappers.jl) will give you type stability for a fixed (?) cost. Its use case is different, but if you are wrestling with type instabilities, take a look at it first.
- [FunctionWranglers.jl](https://github.com/tisztamo/FunctionWranglers.jl) allows fast, inlined execution of functions provided in an array - for that use case it is a better choice than Catwalk.jl.

Miss a package? Please send a PR!