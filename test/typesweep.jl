
const TYPE_COUNT = 1000
const INTERVAL_LENGTH = 50

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
    @time for i = 1:3e6
        f(center, jitctx)
    end
end

function f_nojit(center)
    x = getx(center)
    g(x)
end

function kernel_nojit(center)
    @time for i = 1:3e6
        f_nojit(center)
    end
end

@testset "Type sweep" begin
    optimizer = RuntimeOptimizer()
    JIT.add_boost!(
        optimizer,
        CallBoost(
            :g,
            profilestrategy = SparseProfile(0.1),
            optimizer       = JIT.TopNOptimizer(50)
        )
    )
    @time for r = 1:300
        @show center = Int(round(r)) % TYPE_COUNT + 1
        kernel_nojit(center)
    end

    @time for r = 1:300
        JIT.step!(optimizer)
        jitctx = ctx(optimizer)
        @show center = Int(round(r)) % TYPE_COUNT + 1
        kernel(center, jitctx)
    end
end
