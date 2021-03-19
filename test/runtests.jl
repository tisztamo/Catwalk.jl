using JIT
using Test
using Random
using BenchmarkTools

Random.seed!(42)

# To run only selected tests, use e.g.:
#
#   using Pkg; Pkg.test("JIT", test_args=["scheduling"])
#
enabled_tests = lowercase.(ARGS)
function addtests(fname)
    key = lowercase(splitext(fname)[1])
    if isempty(enabled_tests) || key in enabled_tests
        include(fname)
    end
end

addtests("typelist.jl")
addtests("costmodel.jl")
addtests("scheduling.jl")
addtests("typesweep.jl")
