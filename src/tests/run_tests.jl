include("obj_func.jl")

function run_alns_test_on_instance(deck, instances; patience = 20000)
    
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
        push!(delays, wait_time(d,c))
        push!(numcarg,count(x->!isnothing(x),c))

    end
    println("ALNS: ", mean(times))
    println("Mean comp. time: ", mean(times))
    println("Mean delay: ", mean(delays))
    println(shifts)
    println("Mean shifts: ", mean(shifts))
    println("Mean num. of caergo: ", mean(numcarg),"/",length(instances[1]))
    println("Mean obj. val.: ", mean(obvals))
    println("--------------------------------")




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
        push!(obvals,evaluate_sol(d,c))
        push!(delays, wait_time(d,c))
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

function run_multiple_tests(deck,instlist; patience=10000)
    times = []
    delays = []
    obvals = []
    shifts = []
    numcarg = []
    gtimes = []
    gdelays = []
    gobvals = []
    gshifts = []
    gnumcarg = []
    
    for instances in instlist
        o,t,timeatport,s,nc = run_alns_test_on_instance(deck, instances; patience = patience)
        push!(times,t)
        push!(delays,timeatport)
        push!(obvals,o)
        push!(shifts,s)
        push!(numcarg,nc)
        
        o,t,timeatport,s,nc = run_grasp_test_on_instance(deck, instances)
        push!(gtimes,t)
        push!(gdelays,timeatport)
        push!(gobvals,o)
        push!(gshifts,s)
        push!(gnumcarg,nc)
    
    end

    for i in 1:length(instlist)
        println("results for 1st instance set")
        println("--------------------------------")
        println("ALNS:")
        println("Obj.Val: ", obvals[i])
        println("Shifts:  ", shifts[i])
        println("Time at port : ", delays[i])
        println("Num. of cargo: ", numcarg[i])
        println("Time: ", times[i])
        println(" ")
        println("GRASP:")
        println("Obj.Val: ", gobvals[i])
        println("Shifts:  ", gshifts[i])
        println("Time at port : ", gdelays[i])
        println("Num. of cargo: ", gnumcarg[i])
        println("Time: ", gtimes[i])
    end
        
        
end