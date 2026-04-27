

function run_alns_test_on_instance(deck, instances; patience = 10000)
    
    times = []
    delays = []
    obvals = []
    shifts = []
    numcarg = []


    for cargo in instances
        d,c,h,t = alns_hansen_basket(deck, cargo, early_stop_thres=patience, print_status=false,grasp_its=2000)
        push!(times,t)
        push!(shifts, min_shift_all_cargo(d))
        push!(obvals,h[end])
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