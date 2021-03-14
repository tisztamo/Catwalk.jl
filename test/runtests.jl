using JIT
using Test
using Random
using BenchmarkTools

# To run only selected tests, use e.g.:
#
#   Pkg.test("JIT", test_args=["scheduling"])
#
enabled_tests = lowercase.(ARGS)
function addtests(fname)
    key = lowercase(splitext(fname)[1])
    if isempty(enabled_tests) || key in enabled_tests
        Random.seed!(42)
        include(fname)
    end
end

addtests("encode.jl")
addtests("scheduling.jl")
