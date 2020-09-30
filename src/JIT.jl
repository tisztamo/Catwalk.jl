module JIT

export compile, compile, count_subtypes, @demo, createq

struct JITFn{TOp, TFixType, TNext}
    op::TOp
    next::TNext
end

compile(op) = JITFn{typeof(op), Nothing, Nothing}(op, nothing)
compile(op, fixtype) = JITFn{typeof(op), fixtype, Nothing}(op, nothing)
compile(op, fixtype, fixtypes...) = begin
    next = compile(op, fixtypes)
    return JITFn{typeof(op), fixtype, typeof(next)}(op, next)
end

@inline (j::JITFn{TOp, TFixType, TNext})(arg) where {TOp, TFixType, TNext} = begin
    if arg isa TFixType
        return j.op(arg)
    end
    if TNext === Nothing
        return j.op(arg)
    end
    return TNext(arg)
end

end # module
