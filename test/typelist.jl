const sample_typelists = [
    (Int,),
    (Int, Float16),
    (Dict{Any,Any},),
    (Dict{Any,Any}, Int, Integer),
    ()
]

@testset "Encode-decode" begin
    @test JIT.encode(Int)() isa JIT.TypeListItem
    for typelist in sample_typelists
        @test JIT.decode(JIT.encode(typelist...)) == typelist
    end
end

@testset "findfirst" begin
    for typelist in sample_typelists
        for l = 1:5
            if length(typelist) >= l
                @test findfirst(typelist[l], JIT.encode(typelist...)) == l
            end
        end
    end    
end