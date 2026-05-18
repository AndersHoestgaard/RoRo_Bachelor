include(joinpath(pwd(), "src/Heuristics/run_alns.jl"))

function param_tune(
    deck,
    train_cargos,
    param2test,
    a,
    b,
    step;
    reps = 3,                 
    alns_runtime = 25,
    segment = 100,
    eta = 0.1,
    sig1 = 33,
    sig2 = 9,
    sig3 = 3,
    xi=0.4,
    patience = 10000
)

    res = Dict()

    for p in a:step:b
        println("Testing $param2test = $p")
        reslist = Float64[]

        for cargo in train_cargos
            instance_results = Float64[]

            for r in 1:reps
                # Build kwargs dict
                kwargs = Dict(
                    :time_lim => alns_runtime,
                    :segment => segment,
                    :eta => eta,
                    :sig1 => sig1,
                    :sig2 => sig2,
                    :sig3 => sig3,
                    :xi => xi
                )

                # Override tuned parameter
                kwargs[param2test] = p

                d, c, h, _ = alns_hansen_basket(deck, cargo; kwargs..., print_status=false,early_stop_thres=patience)

                push!(instance_results, h[end])
            end

            # Average over repetitions for this cargo
            push!(reslist, mean(instance_results))
        end

        # Average over all cargos
        res[p] = mean(reslist)
    end

    return res
end