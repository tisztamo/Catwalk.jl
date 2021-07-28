var documenterSearchIndex = {"docs":
[{"location":"usage/","page":"Usage","title":"Usage","text":"EditURL = \"https://github.com/tisztamo/Catwalk.jl/blob/main/docs/src/usage.jl\"","category":"page"},{"location":"usage/#Usage","page":"Usage","title":"Usage","text":"","category":"section"},{"location":"usage/","page":"Usage","title":"Usage","text":"Let's say you have a long-running calculation, organized into batches:","category":"page"},{"location":"usage/","page":"Usage","title":"Usage","text":"const NUM_BATCHES = 1000\n\nfunction runbatches()\n    for batchidx = 1:NUM_BATCHES\n        hotloop()\n        # Log progress, etc.\n    end\nend","category":"page"},{"location":"usage/","page":"Usage","title":"Usage","text":"The hot loop calls the type-unstable function get_some_x() and passes its result to a relatively cheap calculation calc_with_x().","category":"page"},{"location":"usage/","page":"Usage","title":"Usage","text":"const NUM_ITERS_PER_BATCH = 1_000_000\n\nfunction hotloop()\n    for i = 1:NUM_ITERS_PER_BATCH\n        x = get_some_x(i)\n        calc_with_x(x)\n    end\nend\n\nconst xs = Any[1, 2.0, ComplexF64(3.0, 3.0)]\nget_some_x(i) = xs[i % length(xs) + 1]\n\nconst result = Ref(ComplexF64(0.0, 0.0))\n\nfunction calc_with_x(x)\n    result[] += x\nend","category":"page"},{"location":"usage/","page":"Usage","title":"Usage","text":"As get_some_x is not type-stable, calc_with_x must be dynamically dispatched, which slows down the calculation.","category":"page"},{"location":"usage/","page":"Usage","title":"Usage","text":"Sometimes it is not feasible to type-stabilize get_some_x. Catwalk.jl is here for those cases.","category":"page"},{"location":"usage/","page":"Usage","title":"Usage","text":"You mark hotloop, the outer function with the @jit macro and provide the name of the dynamically dispatched function and the argument to operate on (the API will hopefully improve in the future). You also have to add an extra argument named jitctx to the jit-ed function:","category":"page"},{"location":"usage/","page":"Usage","title":"Usage","text":"using Catwalk\n\n@jit calc_with_x x function hotloop_jit(jitctx)\n    for i = 1:NUM_ITERS_PER_BATCH\n        x = get_some_x(i)\n        calc_with_x(x)\n    end\nend","category":"page"},{"location":"usage/","page":"Usage","title":"Usage","text":"The Catwalk optimizer will provide you the jitctx context which you have to pass to the jit-ed function manually. Also, every batch needs a bit housekeeping to drive the Catwalk optimizer:","category":"page"},{"location":"usage/","page":"Usage","title":"Usage","text":"function runbatches_jit()\n    jit = Catwalk.JIT() ## Also works inside a function (no eval used)\n    for batch = 1:NUM_BATCHES\n        Catwalk.step!(jit)\n        hotloop_jit(Catwalk.ctx(jit)) # Dynamic dispatch is \"pulled out\" from the hot loop to this call\n    end\nend","category":"page"},{"location":"usage/","page":"Usage","title":"Usage","text":"Note that the body of the batch can be arbitrarily complex, not just a simple for loop like in this example. See a more complex test case.","category":"page"},{"location":"usage/","page":"Usage","title":"Usage","text":"Yes, it is a bit complicated to integrate your code with Catwalk, but it may worth the effort:","category":"page"},{"location":"usage/","page":"Usage","title":"Usage","text":"result[] = ComplexF64(0, 0)\n@time runbatches_jit()\n\n# 4.608471 seconds (4.60 M allocations: 218.950 MiB, 0.56% gc time, 21.68% compilation time)\n\njit_result = result[]\n\nresult[] = ComplexF64(0, 0)\n@time runbatches()\n\n# 23.387341 seconds (1000.00 M allocations: 29.802 GiB, 7.71% gc time)","category":"page"},{"location":"usage/","page":"Usage","title":"Usage","text":"And the results are the same:","category":"page"},{"location":"usage/","page":"Usage","title":"Usage","text":"jit_result == result[] || error(\"JIT must be a no-op!\")","category":"page"},{"location":"usage/","page":"Usage","title":"Usage","text":"Please note that the speedup depends on the portion of the runtime spent in dynamic dispatch, which is most likely smaller in your case than in this contrived example.","category":"page"},{"location":"usage/","page":"Usage","title":"Usage","text":"You can find this example under docs/src/usage.jl in the repo.","category":"page"},{"location":"usage/","page":"Usage","title":"Usage","text":"","category":"page"},{"location":"usage/","page":"Usage","title":"Usage","text":"This page was generated using Literate.jl.","category":"page"},{"location":"tuning/#Configuration-and-tuning","page":"Configuration & tuning","title":"Configuration & tuning","text":"","category":"section"},{"location":"tuning/","page":"Configuration & tuning","title":"Configuration & tuning","text":"Catwalk.jl comes with reasonable default configs, but it also allows you to tweak its behavior.","category":"page"},{"location":"tuning/","page":"Configuration & tuning","title":"Configuration & tuning","text":"To monitor its inner workings, start Julia with JULIA_DEBUG=Catwalk.","category":"page"},{"location":"tuning/#Set-up-call-sites","page":"Configuration & tuning","title":"Set up call sites","text":"","category":"section"},{"location":"tuning/","page":"Configuration & tuning","title":"Configuration & tuning","text":"As most of the configuration is done per call site, first you have to set up the call sites with instantiating CallBoosts and provide them to the JIT compiler.","category":"page"},{"location":"tuning/","page":"Configuration & tuning","title":"Configuration & tuning","text":"boost1 = Catwalk.CallBoost(:calc_with_x)\nboost2 = Catwalk.CallBoost(:another_site)\n\njit = Catwalk.JIT(boost1, boost2)\n\n# alternatively: Catwalk.add_boost!(jit, boost1)","category":"page"},{"location":"tuning/#Disable-exploring","page":"Configuration & tuning","title":"Disable exploring","text":"","category":"section"},{"location":"tuning/","page":"Configuration & tuning","title":"Configuration & tuning","text":"When all the call sites are set up, you can turn off exploring:","category":"page"},{"location":"tuning/","page":"Configuration & tuning","title":"Configuration & tuning","text":"jit = Catwalk.JIT(boost1, boost2; explorerfactory = Catwalk.NoExplorer)","category":"page"},{"location":"tuning/#Customize-Profiling","page":"Configuration & tuning","title":"Customize Profiling","text":"","category":"section"},{"location":"tuning/","page":"Configuration & tuning","title":"Configuration & tuning","text":"Currently only the FullProfiler is available, but it only runs in randomly selected batches, driven by the SparseProfile profile strategy. To change the sparsity of profiling (default is 1%), use:","category":"page"},{"location":"tuning/","page":"Configuration & tuning","title":"Configuration & tuning","text":"boost1 = Catwalk.CallBoost(:calc_with_x; profilestrategy = Catwalk.SparseProfile(0.02))","category":"page"},{"location":"tuning/","page":"Configuration & tuning","title":"Configuration & tuning","text":"The profiler will run during the first two rounds in every case, so if you are sure that the distribution of dispatched types does not change significantly during the full run, you can set the sparsity to 0.","category":"page"},{"location":"tuning/#Tune-the-optimizer","page":"Configuration & tuning","title":"Tune the optimizer","text":"","category":"section"},{"location":"tuning/","page":"Configuration & tuning","title":"Configuration & tuning","text":"You can configure different optimizers for every call site. Currently only the TopNOptimizer if available, which generates fast routes for up to the given number of types (10 by default).","category":"page"},{"location":"tuning/","page":"Configuration & tuning","title":"Configuration & tuning","text":"boost1 = Catwalk.CallBoost(:calc_with_x; optimizer = Catwalk.TopNOptimizer(50))","category":"page"},{"location":"tuning/","page":"Configuration & tuning","title":"Configuration & tuning","text":"I plan to add an optimizer that calculates marginal utility to decide the number of fast routes, so that tuning N becomes unnecessary.","category":"page"},{"location":"tuning/#Tune-compilation-overhead","page":"Configuration & tuning","title":"Tune compilation overhead","text":"","category":"section"},{"location":"tuning/","page":"Configuration & tuning","title":"Configuration & tuning","text":"The optimizer accepts the compile_threshold argument (1.04 by default). Set it to a higher value if you think there is too much compilation.","category":"page"},{"location":"tuning/","page":"Configuration & tuning","title":"Configuration & tuning","text":"The optimizer maintains a list of all previous compilations and finds the best one from them for the current profile, based on the cost model. If the cost of that historic best compilation is not larger than the cost of the ideal one generated for the current profile, multiplied with compile_threshold, then the historic one will be reused.","category":"page"},{"location":"tuning/#Customize-the-cost-model","page":"Configuration & tuning","title":"Customize the cost model","text":"","category":"section"},{"location":"tuning/","page":"Configuration & tuning","title":"Configuration & tuning","text":"The optimizer also accepts a cost model. The default cost model is the following (costs are measured in clock cycles):","category":"page"},{"location":"tuning/","page":"Configuration & tuning","title":"Configuration & tuning","text":"const basemodel = DefaultDispatchCostModel(\n    skip                = 3,\n    static_dispatch     = 8,\n    dynamic_dispatch    = 100,\n)","category":"page"},{"location":"tuning/","page":"Configuration & tuning","title":"Configuration & tuning","text":"Where","category":"page"},{"location":"tuning/","page":"Configuration & tuning","title":"Configuration & tuning","text":"skip is the cost of an if x isa T: Checking if the current type of the jitted argument equals to a predefined one.\nstatic_dispatch is the cost of a type-stabilized route, not including the skip-cost of that route.\ndynamic_dispatch is the original cost of the call with a full dynamic dispatch.","category":"page"},{"location":"tuning/","page":"Configuration & tuning","title":"Configuration & tuning","text":"As the cost of static and dynamic dispatch varies between call sites, you may want to configure the cost model for your case. (It is also possible to define new model types, but it is not documented nor tested yet.)","category":"page"},{"location":"tuning/#A-fully-tuned-example","page":"Configuration & tuning","title":"A fully tuned example","text":"","category":"section"},{"location":"tuning/","page":"Configuration & tuning","title":"Configuration & tuning","text":"    optimizer = JIT(;explorerfactory = Catwalk.NoExplorer)\n    Catwalk.add_boost!(\n        optimizer,\n        Catwalk.CallBoost(\n            :calc_with_x,\n            profilestrategy  =  Catwalk.SparseProfile(0.02),\n            optimizer        =  Catwalk.TopNOptimizer(50;\n                                    compile_threshold = 1.1,\n                                    costmodel = Catwalk.DefaultDispatchCostModel(\n                                        skip                = 2,\n                                        static_dispatch     = 8,\n                                        dynamic_dispatch    = 1000,\n                                    )\n                                ),\n        )\n    )","category":"page"},{"location":"howitworks/#How-it-works?","page":"How it works?","title":"How it works?","text":"","category":"section"},{"location":"howitworks/#Generated-code","page":"How it works?","title":"Generated code","text":"","category":"section"},{"location":"howitworks/","page":"How it works?","title":"How it works?","text":"The @jit macro turns the outer function to a @generated one, so that we can recompile with reoptimized source code at will.","category":"page"},{"location":"howitworks/","page":"How it works?","title":"How it works?","text":"The optimized code looks like this:","category":"page"},{"location":"howitworks/","page":"How it works?","title":"How it works?","text":"    x = get_some_x(i)\n    if x isa FrequentType1\n        calc_with_x(x) # Fast type-stable route\n    elseif x isa FrequentType2\n        calc_with_x(x) # Fast type-stable route\n    .\n    .\n    .\n    else\n        calc_with_x(x) # Fallback to the dynamically dispatched call\n    end","category":"page"},{"location":"howitworks/#Iterated-staging","page":"How it works?","title":"Iterated staging","text":"","category":"section"},{"location":"howitworks/","page":"How it works?","title":"How it works?","text":"Catwalk.jl uses a technique I call \"iterated staging\", which is essentially an outer loop which repetitively recompiles parts of the loop body.","category":"page"},{"location":"howitworks/","page":"How it works?","title":"How it works?","text":"Recompilation happens by encoding the current \"stage\" - the list of concrete types to speed up and the profiler config - into a type and passing an instance of that type, called the \"JIT context\" to the inner function in the loop body.","category":"page"},{"location":"howitworks/","page":"How it works?","title":"How it works?","text":"Only the type of the JIT context drives the compilation process, as it is the only data available to the @generated inner function.","category":"page"},{"location":"howitworks/#JIT-context-basics","page":"How it works?","title":"JIT context basics","text":"","category":"section"},{"location":"howitworks/","page":"How it works?","title":"How it works?","text":"This is how the context looks like:","category":"page"},{"location":"howitworks/","page":"How it works?","title":"How it works?","text":"struct CallCtx{TProfiler, TFixtypes}\n    profiler::TProfiler\nend","category":"page"},{"location":"howitworks/","page":"How it works?","title":"How it works?","text":"Where TFixTypes encodes everything needed to generate the dispatch code, and TProfiler describes the profiler configuration used in the current batch.","category":"page"},{"location":"howitworks/","page":"How it works?","title":"How it works?","text":"TFixTypes is built with recursive type parameters that encode the stabilized types as a linked list. For example, to speed up FrequentType1 and FrequentType2, the optimizer generates a concrete type by recursively parametrizing the TypeListItem generic type:","category":"page"},{"location":"howitworks/","page":"How it works?","title":"How it works?","text":"struct TypeListItem{TThis, TNext} end\nstruct EmptyTypeList end\n\nCatwalk.encode(FrequentType1, FrequentType2)\n\n# Catwalk.TypeListItem{FrequentType1, Catwalk.TypeListItem{FrequentType2, Catwalk.EmptyTypeList}}","category":"page"},{"location":"howitworks/","page":"How it works?","title":"How it works?","text":"Passing this \"type list\" as part of the JIT context allows the @generated function to generate the type-stable routes.","category":"page"},{"location":"howitworks/#Profilers","page":"How it works?","title":"Profilers","text":"","category":"section"},{"location":"howitworks/","page":"How it works?","title":"How it works?","text":"The other part of the context is the profiler. Two profilers are implemented at the time:","category":"page"},{"location":"howitworks/","page":"How it works?","title":"How it works?","text":"struct NoProfiler <: Profiler end\n\nstruct FullProfiler <: Profiler\n    typefreqs::DataTypeFrequencies\nend","category":"page"},{"location":"howitworks/","page":"How it works?","title":"How it works?","text":"The FullProfiler collects statistics from every call. It logs a call faster than a dynamic dispatch, but running it in every batch would still eat most of the cake, so it is sparsely used, with 1% probability by default (It is always active during the first two batches). ","category":"page"},{"location":"howitworks/#Explorer-and-the-full-JIT-context","page":"How it works?","title":"Explorer and the full JIT context","text":"","category":"section"},{"location":"howitworks/","page":"How it works?","title":"How it works?","text":"The last missing part is the explorer, which automatically connects the JIT compiler with the @jit-ed functions that run under its supervision.","category":"page"},{"location":"howitworks/","page":"How it works?","title":"How it works?","text":"This connection is not trivial because the @jit macro is only applied to a single function which is somewhere \"inside\" the batch, potentially in another package than the outer loop. It is possible to configure the optimizer manually, but the Explorer can automatically find the @jit-ed call sites that are called in the batch.","category":"page"},{"location":"howitworks/","page":"How it works?","title":"How it works?","text":"As a single JIT compiler can handle multiple call sites, the jitctx in reality is not a single CallCtx as described earlier, but a NamedTuple of them, plus an explorer:","category":"page"},{"location":"howitworks/","page":"How it works?","title":"How it works?","text":"struct OptimizerCtx{TCallCtxs, TExplorer}\n    callctxs::TCallCtxs # NamedTuple of `CallCtx`s\n    explorer::TExplorer\nend","category":"page"},{"location":"howitworks/","page":"How it works?","title":"How it works?","text":"The explorer holds its id in its type, because exploration happens during compilation, when only its type is available.","category":"page"},{"location":"howitworks/","page":"How it works?","title":"How it works?","text":"struct BasicExplorer{TOptimizerId} <: Explorer end","category":"page"},{"location":"howitworks/","page":"How it works?","title":"How it works?","text":"Here Catwalk - just like many other meta-heavy Julia packages - violates the rule that a @generated function is not \"allowed\" to access mutable global state. The explorer logs the call site to a global dict, keyed with its id, from where the JIT compiler can read it out during the next batch.","category":"page"},{"location":"howitworks/","page":"How it works?","title":"How it works?","text":"It seems impossible to send back information from the compilation process without breaking this rule, and pushing the exploration to the tight loop is not feasible.","category":"page"},{"location":"howitworks/","page":"How it works?","title":"How it works?","text":"I think that this violation is acceptible (note that RuntimeGeneratedFunctions also does the same), but it is possible to turn off the Explorer, as described in the tuning guide.","category":"page"},{"location":"#Catwalk.jl-Intro","page":"Catwalk.jl Intro","title":"Catwalk.jl Intro","text":"","category":"section"},{"location":"","page":"Catwalk.jl Intro","title":"Catwalk.jl Intro","text":"Catwalk.jl can speed up long-running Julia processes by minimizing the overhead of dynamic dispatch. It is a JIT compiler that continuosly re-optimizes dispatch code based on data collected at runtime.","category":"page"},{"location":"","page":"Catwalk.jl Intro","title":"Catwalk.jl Intro","text":"(Image: Speedup demo) source code of this test","category":"page"},{"location":"","page":"Catwalk.jl Intro","title":"Catwalk.jl Intro","text":"It profiles user-specified call sites, estimating the distribution of dynamically dispatched types during runtime, and generates fast static routes for the most frequent ones on the fly.","category":"page"},{"location":"","page":"Catwalk.jl Intro","title":"Catwalk.jl Intro","text":"The statistical profiler has very low overhead and can be configured to handle situations where the distribution of dispatched types changes relatively fast.","category":"page"},{"location":"","page":"Catwalk.jl Intro","title":"Catwalk.jl Intro","text":"To minimize compilation overhead, recompilation only occurs when the distribution changed enough and the tunable cost model predicts significant speedup compared to the best version that was previously compiled.","category":"page"},{"location":"#When-to-use-this-package","page":"Catwalk.jl Intro","title":"When to use this package","text":"","category":"section"},{"location":"","page":"Catwalk.jl Intro","title":"Catwalk.jl Intro","text":"Catwalk.jl focuses on use cases when it is not feasible to list the dynamically dispatched concrete types in the source code of the call site, and when the calculation is relatively complex or composed from different codebases. For simpler use cases, or when compilation overhead should be minimal, you may find better alternatives (See the list below).","category":"page"},{"location":"","page":"Catwalk.jl Intro","title":"Catwalk.jl Intro","text":"Catwalk.jl assumes the followings:","category":"page"},{"location":"","page":"Catwalk.jl Intro","title":"Catwalk.jl Intro","text":"The process is long running: several seconds, but possibly minutes are needed to break even after the initial compilation overhead.\nFew dynamically dispatched call sites contribute significantly to the running time (dynamic dispatch in a hot loop).\nYou can modify the source code around the interesting call sites (add a macro call), and calculation is organized into batches.","category":"page"},{"location":"#Alternatives","page":"Catwalk.jl Intro","title":"Alternatives","text":"","category":"section"},{"location":"","page":"Catwalk.jl Intro","title":"Catwalk.jl Intro","text":"SingleDispatchArrays.jl gives you fast single dispatch for arrays of non-homogeneous elements.\nJuliaFolds packages in general try to do a weaker version of this, as discussed in: Tail-call optimization and function-barrier -based accumulation in loops.\nManualDispatch.jl can serve you better in less dynamic cases, when it is feasible to list the dynamically dispatched types in the source code.\nIn even simpler cases using unions instead of a type hierarchy may allow the Julia compiler to \"split the union\". See for example List performance improvent by Union-typed tail in DataStructures.jl.\nFunctionWrappers.jl will give you type stability for a fixed (?) cost. Its use case is different, but if you are wrestling with type instabilities, take a look at it first.\nFunctionWranglers.jl allows fast, inlined execution of functions provided in an array - for that use case it is a better choice than Catwalk.jl.","category":"page"},{"location":"","page":"Catwalk.jl Intro","title":"Catwalk.jl Intro","text":"Miss a package? Please send a PR!","category":"page"}]
}
