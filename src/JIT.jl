"""
    JIT.jl

An optimizing Just In Time compiler written in Julia.
"""
module JIT

export compile

abstract type AbstractCompiledFn end

struct CompiledFn{TGeneralOp, TOptimizedOp} <: AbstractCompiledFn
    general::TGeneralOp
    opt::TOptimizedOp
    fixtypes::Union{Nothing, Tuple{Vararg{Type}}}
end

function compile(op; fixtypes=nothing)
    result = op
    result = fixtype(result, fixtypes...) # Apply passes TODO implement them as a plugin
    return CompiledFn(op, result, fixtypes) # Present the result
end

"""
    struct FixedType{TOp, TFixType, TNext}
        op::TOp
        next::TNext
    end

This functor is the IR for a JIT compilation.

It wraps a general / the original version of, the function
"""
struct FixedType{TOp, TFixType, TNext} <: AbstractCompiledFn
    op::TOp
    next::TNext
end

fixtype(op) = FixedType{typeof(op), Nothing}(op, nothing)
fixtype(op, _fixtype) = FixedType{typeof(op), _fixtype, Nothing}(op, nothing)
fixtype(op, _fixtype, fixtypes...) = begin
    next = fixtype(op, fixtypes...)
    return FixedType{typeof(op), _fixtype, typeof(next)}(op, next)
end

@inline function (j::FixedType{TOp, TFixType, TNext})(arg) where {TOp, TFixType, TNext}
    if arg isa TFixType
        return j.op(arg)
    end
    if TNext === Nothing
        return j.op(arg)
    end
    return TNext(arg)
end

@inline function (j::CompiledFn)(arg)
    j.opt(arg)
end

end # module
