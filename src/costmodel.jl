ClockCycle = Int

abstract type DispatchCostModel end

Base.@kwdef struct DefaultDispatchCostModel <: DispatchCostModel
    skip::ClockCycle
    static_dispatch::ClockCycle
    dynamic_dispatch::ClockCycle
end
basemodel = DefaultDispatchCostModel(
    skip                = 4,
    static_dispatch     = 10,
    dynamic_dispatch    = 150,
)

function costof(
    typefreqs::IdDict{Type, Int},
    fixtypes,
    costmodel::DispatchCostModel
    )
    total = 0
    for (type, freq) in pairs(typefreqs)
        skipcost, isstatic = calc_skipcost(type, freq, fixtypes, costmodel)
        dispatchcost = isstatic ? costmodel.static_dispatch : costmodel.dynamic_dispatch
        total += skipcost + dispatchcost
    end
    return total
end

function calc_skipcost(type, freq, fixtypes, costmodel)
    idx = findfirst(type, fixtypes)
    perskip_cost = costmodel.skip * freq
    if isnothing(idx)
        return perskip_cost * length(fixtypes), false
    end
    return perskip_cost * idx, true
end