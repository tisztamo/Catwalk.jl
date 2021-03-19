const testmodel = JIT.DefaultDispatchCostModel(
    skip                = 1,
    static_dispatch     = 10,
    dynamic_dispatch    = 100,
)

const testfreqs = IdDict{Type, Int}(
    Int => 3,
    Float16 => 111,
    Float32 => 5,
    Float64 => 7,
)

@testset "Cost Model" begin
    @test JIT.costof(testfreqs, JIT.encode(Float16, Int, Float32), testmodel) ==
    (
        testfreqs[Int] * 2 * testmodel.skip + testmodel.static_dispatch +
        testfreqs[Float16] * 1 * testmodel.skip + testmodel.static_dispatch +
        testfreqs[Float32] * 3 * testmodel.skip + testmodel.static_dispatch +
        testfreqs[Float64] * 3 + testmodel.dynamic_dispatch
    )
end