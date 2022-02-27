# Catwalk.jl

[![DOI](https://zenodo.org/badge/299561138.svg)](https://zenodo.org/badge/latestdoi/299561138)

[![Documentation](https://img.shields.io/badge/docs-dev-blue.svg)](https://tisztamo.github.io/Catwalk.jl/dev/)
[![CI](https://github.com/tisztamo/Catwalk.jl/actions/workflows/ci.yml/badge.svg)](https://github.com/tisztamo/Catwalk.jl/actions/workflows/ci.yml)
![Lifecycle](https://img.shields.io/badge/lifecycle-maturing-blue.svg)
[![ColPrac: Contributor Guide on Collaborative Practices for Community Packages](https://img.shields.io/badge/ColPrac-Contributor's%20Guide-blueviolet)](https://github.com/SciML/ColPrac)

Catwalk.jl can speed up long-running Julia processes by minimizing the
overhead of dynamic dispatch. It is a JIT compiler that continuosly
re-optimizes dispatch code based on data collected at runtime.

![Speedup demo](docs/src/assets/catwalk-speeddemo.gif)
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

[Documentation (dev)](https://tisztamo.github.io/Catwalk.jl/dev/)
