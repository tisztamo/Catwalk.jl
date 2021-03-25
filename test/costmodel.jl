const testmodel = Catwalk.DefaultDispatchCostModel(
    skip                = 1,
    static_dispatch     = 10,
    dynamic_dispatch    = 100,
)

const testfreqs = Catwalk.DataTypeFrequencies()
for i =1:3 Catwalk.increment!(testfreqs, Int) end
for i =1:111 Catwalk.increment!(testfreqs, Float16) end
for i =1:5 Catwalk.increment!(testfreqs, Float32) end
for i =1:7 Catwalk.increment!(testfreqs, Float64) end

@testset "Cost Model" begin
    @test Catwalk.costof(values(testfreqs), Catwalk.encode(Float16, Int, Float32), testmodel) ==
    (
        3   * (2 * testmodel.skip + testmodel.static_dispatch) +
        111 * (1 * testmodel.skip + testmodel.static_dispatch) +
        5   * (3 * testmodel.skip + testmodel.static_dispatch) +
        7   * (3 + testmodel.dynamic_dispatch)
    )
end