struct TypeListItem{TThis, TNext} end
struct EmptyTypeList end
const TypeList = Union{EmptyTypeList, TypeListItem}

encode() = EmptyTypeList
encode(t) = TypeListItem{t, EmptyTypeList}
encode(t, ts...) = TypeListItem{t, encode(ts...)}

decode(t::Tuple) = t
decode(::Type{EmptyTypeList}) = ()
decode(::Type{TypeListItem{TThis, EmptyTypeList}}) where TThis = (TThis,)
decode(::Type{TypeListItem{TThis, TNext}}) where {TThis, TNext} = (TThis, decode(TNext)...)

Base.length(::Type{EmptyTypeList}) = 0
function Base.length(::Type{TypeListItem{TThis, TNext}}) where {TThis, TNext}
    return 1 + length(TNext)
end

Base.findfirst(::Type, ::Type{EmptyTypeList}) = nothing
function Base.findfirst(t::Type, ::Type{TypeListItem{TThis, TNext}}) where {TThis, TNext}
    t == TThis && return 1
    tailidx = findfirst(t, TNext)
    return isnothing(tailidx) ? nothing : tailidx + 1
end

pretty(::Type{TypeListItem{TThis, TNext}}) where {TThis, TNext} = begin
    return "$(TThis), " * pretty(TNext)
end

pretty(::Type{EmptyTypeList}) = ""

