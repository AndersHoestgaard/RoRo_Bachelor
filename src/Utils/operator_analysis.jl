include(joinpath(pwd(), "src/tests/run_alns.jl"))
include(joinpath(pwd(), "src/Heuristics/alns_arrival_time.jl"))


function op_performace_on_set(deck,instances)
    w_ds_by_iter = []  
    w_rs_by_iter = []
    globdops = nothing
    globrops = nothing
    
    for inst in instances
        best_deck, history, his_w_d, his_w_r, destroy_ops, repair_ops = alns_hansen_basket(deck,inst,ret_weights=true,print_status=false,iterations = 10000)
        push!(w_ds_by_iter, mean(his_w_d))  
        push!(w_rs_by_iter, mean(his_w_r))

        if globdops === nothing
            globdops = destroy_ops
            globrops = repair_ops
        end
    end
    
    mean_tot_d = mean(w_ds_by_iter)
    mean_tot_r = mean(w_rs_by_iter)
    println(mean_tot_d)
    println("Global average destroy operator performance:")
    for (i,op) in enumerate(globdops)
        println("  ", op, ": ", mean_tot_d[i])
    end
    println("\nGlobal average repair operator performance:")
    for (i,op) in enumerate(globrops)
        println("  ", op, ": ", mean_tot_r[i])
    end

    for (i,op) in enumerate(globdops)
        print(round(mean_tot_d[i],digits=2), "&")
    end
    println(" ")
    for (i,op) in enumerate(globrops)
        print(round(mean_tot_r[i],digits=2), "&")
    end
   
    
end

