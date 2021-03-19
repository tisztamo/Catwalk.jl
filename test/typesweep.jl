
const TYPE_COUNT = 100
const INTERVAL_LENGTH = 10

g(x::Val{T}) where T = 42 + T

const vals = [Val(i) for i = 1:TYPE_COUNT]

function getx(center)
    idx = rand(center:(center + INTERVAL_LENGTH - 1))
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
    @time for i = 1:3e6
        f(center, jitctx)
    end
end

@testset "Type sweep" begin
    optimizer = RuntimeOptimizer()
    JIT.add_boost!(
        optimizer,
        CallBoost(
            :g,
            profilestrategy = SparseProfile(0.1),
            optimizer       = JIT.TopNOptimizer(10)
        )
    )
    @time for r = 1:300
        JIT.step!(optimizer)
        jitctx = ctx(optimizer)
        @show center = Int(round(r / 3)) % TYPE_COUNT + 1
        kernel(center, jitctx)
    end
end