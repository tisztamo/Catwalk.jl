const callsites = Dict{Int, Set{Symbol}}() # Optimizer id => jitted function names
const freshcallsites = Dict{Int, Set{Symbol}}() # Call sites found during the current round, not yet jitted

function get_callsites!(optimizerid)
    return get!(callsites, optimizerid) do 
        Set{Symbol}()
    end
end

function get_freshcallsites!(optimizerid)
    return get!(freshcallsites, optimizerid) do 
        Set{Symbol}()
    end
end

function exploreexpr(calledfn, argname)
    fnstr = string(calledfn) # Poor man's quote
    argnamestr = string(argname)
    return quote
        Catwalk.log_callsite(Catwalk.explorer(jitctx), Symbol($fnstr), Symbol($argnamestr))
    end
end

abstract type Explorer end

struct NoExplorer{TOptimizerId} <: Explorer end # Allows only manual registering
function NoExplorer(optimizerid)
    get_callsites!(optimizerid)
    return NoExplorer{optimizerid}()
end

struct BasicExplorer{TOptimizerId} <: Explorer end
function BasicExplorer(optimizerid)
    get_callsites!(optimizerid)
    return BasicExplorer{optimizerid}()
end

optimizerid(::Type{BasicExplorer{TOptimizerId}}) where TOptimizerId = TOptimizerId
optimizerid(::Type{NoExplorer{TOptimizerId}}) where TOptimizerId = TOptimizerId

function register_callsite!(explorer, fnsym)
    push!(callsites[optimizerid(typeof(explorer))], fnsym)
    return nothing
end

log_callsite(::Type{NoExplorer{T}}, calledfn, argname) where T = true

function log_callsite(explorer::Type{BasicExplorer{TOptimizerId}}, calledfn, argname) where TOptimizerId
    calledfns = callsites[TOptimizerId]
    if calledfn in calledfns
        return true
    else
        freshfns = get_freshcallsites!(TOptimizerId)
        if !(calledfn in freshfns)
            @debug "Found call site `$calledfn`, optimizing argument `$argname`."
            push!(freshfns, calledfn)
        end
    end
    return false
end

step!(::NoExplorer) = nothing

function step!(explorer::BasicExplorer{TOptimizerId}) where TOptimizerId
    empty!(freshcallsites[TOptimizerId])
end
