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
