
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

@testset "Type sweep" begin
    optimizer = RuntimeOptimizer()
    JIT.add_boost!(
        optimizer,
        CallBoost(
            :g,
            profilestrategy = SparseProfile(0.01),
            optimizer       = JIT.TopNOptimizer(20)
        )
    )
    println("JIT-ed:")
    @time for r = 1:300
        JIT.step!(optimizer)
        jitctx = ctx(optimizer)
        center = Int(round(r / 3)) % TYPE_COUNT + 1
        kernel(center, jitctx)
    end
    println("non-JIT-ed:")
    @time for r = 1:300
        center = Int(round(r / 3)) % TYPE_COUNT + 1
        kernel_nojit(center)
    end
end