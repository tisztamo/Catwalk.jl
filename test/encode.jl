@testset "Encode-decode" begin
    @test JIT.encode(Int)() isa JIT.TypeListItem
    for typelist in [
        (Int,),
        (Int, Float16),
        (Dict{Any,Any},),
        (Dict{Any,Any}, Int, Integer),
        ()
    ]
        @test JIT.decode(JIT.encode(typelist...)) == typelist
    end
end

