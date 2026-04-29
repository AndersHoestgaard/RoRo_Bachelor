include("obj_func.jl")

function run_alns_test_on_instance(deck, instances; patience = 10000)
    
    times = []
    delays = []
    obvals = []
    shifts = []
    numcarg = []


    for cargo in instances
        d,c,h,t = alns_hansen_basket(deck, cargo, early_stop_thres=patience, print_status=false,grasp_its=500)
        push!(times,t)
        push!(shifts, min_shift_all_cargo(d))
        push!(obvals,evaluate_sol(d,c))
        push!(delays, max(0,wait_time(d,c)-perfect_wait_time(d,c)))
        push!(numcarg,count(x->!isnothing(x),c))

    end

    println("Mean comp. time: ", mean(times))
    println("Mean delay: ", mean(delays))
    println(shifts)
    println("Mean shifts: ", mean(shifts))
    println("Mean num. of caergo: ", mean(numcarg),"/",length(instances[1]))
    println("Mean obj. val.: ", mean(obvals))



    return mean(obvals), mean(times), mean(delays), mean(shifts), mean(numcarg)
end

function run_grasp_test_on_instance(deck, instances)
    
    times = []
    delays = []
    obvals = []
    shifts = []
    numcarg = []


    for cargo in instances
        t1 = time()
        d,c = grasp(deck, cargo,max_iter=1000)
        time_used = time()-t1
        push!(times,time_used)
        push!(shifts, min_shift_all_cargo(d))
        push!(obvals,evaluate_sol(d,c,normalised=true))
        push!(delays, max(0,wait_time(d,c)-perfect_wait_time(d,c)))
        push!(numcarg,count(x->!isnothing(x),c))

    end

    println("Mean comp. time: ", mean(times))
    println("Mean delay: ", mean(delays))
    println(shifts)
    println("Mean shifts: ", mean(shifts))
    println("Mean num. of caergo: ", mean(numcarg),"/",length(instances[1]))
    println("Mean obj. val.: ", mean(obvals))



    return mean(obvals), mean(times), mean(delays), mean(shifts), mean(numcarg)
end