# Configuration & tuning

Catwalk.jl comes with reasonable default configs,
but it also allows you to tweak its behavior.

To monitor its inner workings, start Julia with `JULIA_DEBUG=Catwalk`.

## Set up call sites

As most of the configuration is done per call site,
first you have to set up the call sites with instantiating
`CallBoost`s and provide them to the JIT compiler.

```
boost1 = Catwalk.CallBoost(:calc_with_x)
boost2 = Catwalk.CallBoost(:another_site)

jit = Catwalk.JIT(boost1, boost2)

# alternatively: Catwalk.add_boost!(jit, boost1)
```

## Disable exploring

When all the call sites are set up, you can turn off
exploring:

```
jit = Catwalk.JIT(boost1, boost2; explorerfactory = Catwalk.NoExplorer)
```

## Customize Profiling

Currently only the `FullProfiler` is available,
but it only runs in randomly selected batches,
driven by the `SparseProfile` profile strategy.
To change the sparsity of profiling (default is 1%), use:

```
boost1 = Catwalk.CallBoost(:calc_with_x; profilestrategy = Catwalk.SparseProfile(0.02))
```

The profiler will run during the first two rounds in every case,
so if you are sure that the distribution of dispatched types does
not change significantly during the full run, you can set the sparsity to 0.

## Tune the optimizer

You can configure different optimizers for every call site.
Currently only the `TopNOptimizer` if available, which generates
fast routes for up to the given number of types (10 by default).

```
boost1 = Catwalk.CallBoost(:calc_with_x; optimizer = Catwalk.TopNOptimizer(50))
```

I plan to add an optimizer that calculates marginal utility to decide the
number of fast routes, so that tuning N becomes unnecessary.

### Tune compilation overhead

The optimizer accepts the `compile_threshold` argument (1.04 by default).
Set it to a higher value if you think there is too much compilation.

The optimizer maintains a list of all previous compilations
and finds the best one from them for the current profile,
based on the cost model. If the cost of that historic best
compilation is not larger than the cost of the ideal one generated
for the current profile, multiplied with `compile_threshold`,
then the historic one will be reused.

### Customize the cost model

The optimizer also accepts a cost model. The default cost model is the following (costs are measured in clock cycles):

```
const basemodel = DefaultDispatchCostModel(
    skip                = 3,
    static_dispatch     = 8,
    dynamic_dispatch    = 100,
)
```

Where

- `skip` is the cost of an `if x isa T`: Checking if the current type of the jitted argument equals to a predefined one.
- `static_dispatch` is the cost of a type-stabilized route, *not* including the skip-cost of that route.
- `dynamic_dispatch` is the original cost of the call with a full dynamic dispatch.

As the cost of static and dynamic dispatch varies between call sites, you may want to configure
the cost model for your case. (It is also possible to define new model types, but it is not documented nor tested yet.)

# A fully tuned example

```julia
    optimizer = JIT(;explorerfactory = Catwalk.NoExplorer)
    Catwalk.add_boost!(
        optimizer,
        Catwalk.CallBoost(
            :calc_with_x,
            profilestrategy  =  Catwalk.SparseProfile(0.02),
            optimizer        =  Catwalk.TopNOptimizer(50;
                                    compile_threshold = 1.1,
                                    costmodel = Catwalk.DefaultDispatchCostModel(
                                        skip                = 2,
                                        static_dispatch     = 8,
                                        dynamic_dispatch    = 1000,
                                    )
                                ),
        )
    )
```
