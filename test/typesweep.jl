
const TYPE_COUNT = 100
const INTERVAL_LENGTH = 10
const INNER_CYCLE_LENGTH = 1e6

g(x::Val{T}) where T = 42 + T

const vals = [Val(i) for i = 1:TYPE_COUNT]

function getx(center)
    idx = center + Int(round(INTERVAL_LENGTH * abs(randn())))
    while idx > TYPE_COUNT
        idx -= TYPE_COUNT
    end
    return vals[idx]
end

@jit g (x) function f(center, jitctx)
    x = getx(center)
    g(x)
end

function kernel(center, jitctx)
    for i = 1:INNER_CYCLE_LENGTH
        f(center, jitctx)
    end
end

function f_nojit(center)
    x = getx(center)
    g(x)
end

function kernel_nojit(center)
    for i = 1:INNER_CYCLE_LENGTH
        f_nojit(center)
    end
end

function measure_typesweep(optimizer)
    println("Catwalked:")
    startts = time_ns()
    @time for r = 1:200
        Catwalk.step!(optimizer)
        jitctx = ctx(optimizer)
        center = Int(round(r / 3)) % TYPE_COUNT + 1
        kernel(center, jitctx)
    end
    return time_ns() - startts
end

function measure_typesweep_nojit()
    println("non-Catwalked:")
    startts = time_ns()
    @time for r = 1:200
        center = Int(round(r / 3)) % TYPE_COUNT + 1
        kernel_nojit(center)
    end
    return time_ns() - startts
end

@testset "Type sweep" begin
    println("Measuring performance in a type-sweep scenario")
    optimizer = RuntimeOptimizer()
    Catwalk.add_boost!(
        optimizer,
        CallBoost(
            :g,
            profilestrategy = SparseProfile(0.01),
            optimizer       = Catwalk.TopNOptimizer(20)
        )
    )
    jittedtime = measure_typesweep(optimizer)
    normaltime = measure_typesweep_nojit()
    @test normaltime / jittedtime > 1.1
end