const sample_typelists = [
    (Int,),
    (Int, Float16),
    (Dict{Any,Any},),
    (Dict{Any,Any}, Int, Integer),
    ()
]

@testset "Encode-decode" begin
    @test Catwalk.encode(Int)() isa Catwalk.TypeListItem
    for typelist in sample_typelists
        @test Catwalk.decode(Catwalk.encode(typelist...)) == typelist
    end
end

@testset "findfirst" begin
    for typelist in sample_typelists
        for l = 1:5
            if length(typelist) >= l
                @test findfirst(typelist[l], Catwalk.encode(typelist...)) == l
            end
        end
    end    
end