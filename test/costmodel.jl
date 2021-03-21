const testmodel = JIT.DefaultDispatchCostModel(
    skip                = 1,
    static_dispatch     = 10,
    dynamic_dispatch    = 100,
)

const testfreqs = JIT.DataTypeFrequencies()
for i =1:3 JIT.increment!(testfreqs, Int) end
for i =1:111 JIT.increment!(testfreqs, Float16) end
for i =1:5 JIT.increment!(testfreqs, Float32) end
for i =1:7 JIT.increment!(testfreqs, Float64) end

@testset "Cost Model" begin
    @test JIT.costof(values(testfreqs), JIT.encode(Float16, Int, Float32), testmodel) ==
    (
        3   * 2 * testmodel.skip + testmodel.static_dispatch +
        111 * 1 * testmodel.skip + testmodel.static_dispatch +
        5   * 3 * testmodel.skip + testmodel.static_dispatch +
        7   * 3 + testmodel.dynamic_dispatch
    )
end