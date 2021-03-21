function jitexpr(funexpr, callname, argname, fixtypes)
    retval = Expr(:block)
    push!(retval.args, profileexpr(callname, argname))
    for fixtype in fixtypes
        @assert fixtype isa Type
        push!(retval.args, quote
            if $argname isa $fixtype
                return $funexpr
            end
        end)
    end
    push!(retval.args, funexpr)
    return retval
end

function rreplace(expr::Expr, query, transform; symbols=false)
    if query(expr)
        return transform(expr)
    end
    args = [rreplace(subexpr, query, transform; symbols=symbols) for subexpr in expr.args]
    return Expr(expr.head, args...)
end
rreplace(expr::QuoteNode, query, transform; symbols=false) = QuoteNode(rreplace(expr.value, query, transform; symbols=symbols))
rreplace(expr::Symbol, query, transform; symbols=false) = symbols && query(expr) ? transform(expr) : expr
rreplace(expr, query, transform; symbols=false) = expr

function inject_jit(expr, jittedcallname, jittedarg, fixtypes)
    return rreplace(
        expr,
        e -> e isa Expr && e.head == :call && e.args[1] == jittedcallname,
        e -> jitexpr(e, jittedcallname, jittedarg, fixtypes)
    )
end

macro jit(jittedcallname::Symbol, jittedarg::Symbol, expr::Expr)
    @assert expr.head == :function "@jit only supports long-form function declarations"
    signature = expr.args[1]
    body = Expr(:block, expr.args[2].args...)
    explore = exploreexpr(jittedcallname, jittedarg)
    newbody = quote
        Base.@_inline_meta
        if ($explore) # A known, already jitted call
            callctx = JIT.callctx(jitctx, $jittedcallname)
            decoded_fixtypes = JIT.decode(JIT.fixtypes(callctx))
            return JIT.inject_jit(
                $(Expr(:quote, body)),
                $(Expr(:quote, jittedcallname)),
                $(Expr(:quote, jittedarg)),
                decoded_fixtypes
            )
        else
            return $(Expr(:quote, body))
        end
    end
    newfn = Expr(:macrocall, Symbol("@generated"), LineNumberNode(0), Expr(:function, signature, newbody))
    return newfn |> esc
end
