using Random

const TYPE_COUNT = 100
const INTERVAL_LENGTH = 10
const INNER_CYCLE_LENGTH = 1e6

g(x::Val{T}) where T = 42 + T

const vals = [Val(i) for i = 1:TYPE_COUNT]
const rng = Random.MersenneTwister()

function getx(center)
    idx = center + Int(round(INTERVAL_LENGTH * abs(randn(rng))))
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

getcenter(r) = Int(round(r / 10)) % TYPE_COUNT + 1

function measure_typesweep(optimizer)
    println("Catwalked:")
    startts = time_ns()
    @time for r = 1:500
        Catwalk.step!(optimizer)
        kernel(getcenter(r), Catwalk.ctx(optimizer))
    end
    return time_ns() - startts
end

function measure_typesweep_nojit()
    println("non-Catwalked:")
    startts = time_ns()
    @time for r = 1:500
        kernel_nojit(getcenter(r))
    end
    return time_ns() - startts
end


@testset "Type sweep" begin
    println("Measuring performance in a type-sweep scenario")
    optimizer = JIT()
    Catwalk.add_boost!(
        optimizer,
        Catwalk.CallBoost(
            :g,
            profilestrategy  =  Catwalk.SparseProfile(0.02),
            optimizer        =  Catwalk.TopNOptimizer(50;
                                    compile_threshold = 1.1,
                                    costmodel = Catwalk.DefaultDispatchCostModel(
                                        skip                = 1,
                                        static_dispatch     = 8,
                                        dynamic_dispatch    = 1000,
                                    )
                                )
        )
    )
    jittedtime = measure_typesweep(optimizer)
    normaltime = measure_typesweep_nojit()
    @test normaltime / jittedtime > 1.05

    for r = 1:20 # Test result equivalence
        center = getcenter(r)
        Random.seed!(rng, r)
        nojit_result = f_nojit(center)
        Random.seed!(rng, r)
        jit_result = f(center, Catwalk.ctx(optimizer))
        @test jit_result == nojit_result 
    end
end