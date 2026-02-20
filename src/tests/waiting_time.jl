function wait_time(arr_times, handling_time=2, num_operators=2)
    if typeof(arr_times) == Vector{Cargo}
        arr_timestrav = copy(arr_times)
        arr_times = []
        
        for time in arr_timestrav
            push!(arr_times, time.arr)
        end
    end

    busy_until = zeros(Float64, num_operators)

    
    for arr_time in arr_times
        earliest_free = argmin(busy_until)
        start_time = max(arr_time, busy_until[earliest_free])
        finish_time = start_time + handling_time
        busy_until[earliest_free] = finish_time
    end

    return maximum(busy_until)
end
