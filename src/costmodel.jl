ClockCycle = Int

abstract type DispatchCostModel end

Base.@kwdef struct DefaultDispatchCostModel <: DispatchCostModel
    skip::ClockCycle
    static_dispatch::ClockCycle
    dynamic_dispatch::ClockCycle
end
const basemodel = DefaultDispatchCostModel(
    skip                = 3,
    static_dispatch     = 8,
    dynamic_dispatch    = 100,
)

function costof(
    typefreqs, # iterable over Frequency-s 
    fixtypes,
    costmodel::DispatchCostModel = basemodel
    )
    total = 0
    for f in typefreqs
        skipcost, isstatic = calc_skipcost(f.type, f.freq, fixtypes, costmodel)
        dispatchcost = isstatic ? costmodel.static_dispatch : costmodel.dynamic_dispatch
        total += skipcost + dispatchcost
    end
    return total
end

# Return (skipcost, isstatic)
function calc_skipcost(type, freq, fixtypes, costmodel)
    idx = findfirst(type, fixtypes)
    perskip_cost = costmodel.skip * freq
    if isnothing(idx)
        return perskip_cost * length(fixtypes), false
    end
    return perskip_cost * idx, true
end