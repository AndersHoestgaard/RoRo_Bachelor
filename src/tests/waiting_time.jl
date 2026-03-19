function wait_time(i_arr_times, handling_time=4/60, num_operators=5)
    i_arr_times=reshape(i_arr_times,1,:)
    if typeof(i_arr_times) == Vector{Cargo}
        arr_timestrav = copy(i_arr_times)
        i_arr_times = []
        
        for time in arr_timestrav
            push!(i_arr_times, time.arr)
        end
    end

    arr_times = cumsum(i_arr_times,dims = 1)
    


    busy_until = zeros(Float64, num_operators)

    
    for arr_time in arr_times
        earliest_free = argmin(busy_until)
        start_time = max(arr_time, busy_until[earliest_free])
        finish_time = start_time + handling_time
        busy_until[earliest_free] = finish_time
    end

    return maximum(busy_until)
end
