struct TypeListItem{TThis, TNext} end
struct EmptyTypeList end

encode() = EmptyTypeList
encode(t::UnionAll) = error("Do not jit-dispatch on a UnionAll type ($t). It is extremely slow.")
encode(t) = TypeListItem{t, EmptyTypeList}
encode(t, ts...) = TypeListItem{t, encode(ts...)}

decode(t::Tuple) = t
decode(::Type{EmptyTypeList}) = ()
decode(w::Type{TypeListItem{TThis, EmptyTypeList}}) where TThis = (TThis,)
decode(w::Type{TypeListItem{TThis, TNext}}) where {TThis, TNext} = (TThis, decode(TNext)...)

Base.length(::Type{EmptyTypeList}) = 0
function Base.length(::Type{TypeListItem{TThis, TNext}}) where {TThis, TNext}
    return 1 + length(TNext)
end

Base.findfirst(t::Type, ::Type{EmptyTypeList}) = nothing
function Base.findfirst(t::Type, ::Type{TypeListItem{TThis, TNext}}) where {TThis, TNext}
    t == TThis && return 1
    tailidx = findfirst(t, TNext)
    return isnothing(tailidx) ? nothing : tailidx + 1
end