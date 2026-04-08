using Graphs, SimpleWeightedGraphs
function get_all_c_loc(deck) #Get cargo loc. Reverse_cols and Reverserows implemented by chatgpt
    id_cargo = []
    
    for (j,col) in enumerate(eachcol(deck))
        for (i,slot) in enumerate(col)
            if slot >2
                push!(id_cargo, (i,j))   
            end
        end
    end

    return id_cargo
end

function get_ramp_loc(deck) #Get location of ramp slots
    ramp_loc = []
    for (i,row) in enumerate(eachrow(deck)) 
        for (j,slot) in enumerate(row)
            if slot == 2
                push!(ramp_loc,[i,j])
            end
        end
    end
    return ramp_loc
end

function get_graph_for_loading_order(deck) #Model deck as dir. weighted graph. 
    #Always assumes ramp is to the rigth
    m, n = size(deck)

    g = SimpleWeightedDiGraph(m * n)
        
    for i in 1:m
        for j in 1:n
            
            # Skip empty slots and slots that cant be accessed by trucks
            if deck[i,j] == 0 
                continue
            end
            current_node = (i-1)*n + j
            
            # --- NORTH-EAST ---
            if i > 1&& j<n && deck[i-1,j] >0 && deck[i-1,j+1] >0 && deck[i,j+1] >0
                neighbor_node = (i-2)*n + j +1
                cost = maximum([sum([(deck[i-1,j] > 2), (deck[i-1,j+1] > 2),(deck[i,j+1]> 2) ]),0.0001])
                add_edge!(g, current_node, neighbor_node, cost)
            end
            
            # --- WEST ---
            if j > 1 && j<n && deck[i,j-1] != 0
                neighbor_node = (i-1)*n + (j-1)
                
                cost = (deck[i,j-1] > 2 || deck[i,j+1] > 2) ? 1.0 : 0.0001

                add_edge!(g, current_node, neighbor_node, cost)
            end

            # --- SOUTH-EaSt ---
            if i < m && j<n && deck[i+1,j] >0 && deck[i+1,j+1] >0 && deck[i,j+1] >0
                neighbor_node = i*n + j +1
                cost = maximum([sum([(deck[i+1,j] > 2), (deck[i+1,j+1] > 2),(deck[i,j+1] > 2) ]) ,0.0001])
                add_edge!(g, current_node, neighbor_node, cost)
            end

            # --- EAST ---
            if j < n && deck[i,j+1] != 0
                neighbor_node = (i-1)*n + (j+1)
                cost = (deck[i,j+1] > 2) ? 1.0 : 0.0001
                add_edge!(g, current_node, neighbor_node, cost)
            end
        end
    end
    
    return g
end

function loading_order(deck, cargo_on)

    g = get_graph(deck)
    goal_slots = get_ramp_loc(deck)
    m, n = size(deck)
    start_slots = get_all_c_loc(deck)

    # --- Map node → cargo ---
    node_to_cargo = Dict{Int, Any}()
    for i in 1:m, j in 1:n
        node = (i-1)*n + j
        if deck[i,j] > 2   # cargo
            node_to_cargo[node] = cargo_on[i,j]
        end
    end

    # --- Initialize dependency dict ---
    all_cargo = [c for c in cargo_on if c !== nothing]
    V = Dict{Any, Vector{Any}}()
    for c in all_cargo
        V[c] = Any[]
    end

    # --- Main loop ---
    for start_pos in start_slots

        start_node = (start_pos[1]-1)*n + start_pos[2]

        # skip empty
        if !haskey(node_to_cargo, start_node)
            continue
        end

        cargo_A = node_to_cargo[start_node]

        dsp = dijkstra_shortest_paths(g, start_node)
        dists = dsp.dists

        # --- find best goal ---
        min_dist = Inf
        best_goal_node = nothing

        for goal_pos in goal_slots
            goal_node = (goal_pos[1]-1)*n + goal_pos[2]
            if dists[goal_node] < min_dist
                min_dist = dists[goal_node]
                best_goal_node = goal_node
            end
        end

        # --- reconstruct path ---
        path = Int[]
        current = best_goal_node
        if best_goal_node === nothing || isinf(min_dist)
            continue   # skip this cargo
        end
        while current != start_node && current != 0
            pushfirst!(path, current)
            current = dsp.parents[current]
        end

        pushfirst!(path, start_node)

        # --- extract dependencies ---
        for i in 1:length(path)-1
            u = path[i]
            v = path[i+1]

            w = Graphs.weights(g)[u,v]

            if isapprox(w, 1.0; atol=1e-9)
                # blocking cargo at v
                if haskey(node_to_cargo, v)
                    cargo_B = node_to_cargo[v]

                    # A must come before B
                    if !(cargo_B in V[cargo_A])
                        push!(V[cargo_A], cargo_B)
                    end
                end
            end
        end
    end

    return V
end

function wait_time_simple(cargo_on; handling_time=4/60, num_operators=5) # implemented by chatgpt
    all_cargo = cargo_on[cargo_on .!= nothing]

    arr_times = [c.arr for c in all_cargo]
    busy_until = zeros(Float64, num_operators)

    
    for arr_time in arr_times
        earliest_free = argmin(busy_until)
        start_time = max(arr_time, busy_until[earliest_free])
        finish_time = start_time + handling_time
        busy_until[earliest_free] = finish_time
    end

    return maximum(busy_until)
end

function wait_time(deck, cargo_on;
    handling_time = 4/60,
    num_operators = 5,
    percent_arrived = 0.2)

    V = loading_order(deck, cargo_on)

    all_cargo = [c for c in cargo_on if c !== nothing]


    # --- Inter-arrival ---
    arr_times = [c.arr for c in all_cargo]
    k = Int(floor(length(all_cargo) * percent_arrived))
    arr_times[1:k] .= 0.0


    arrival_dict = Dict(c => t for (c,t) in zip(all_cargo, arr_times))

    busy_until = zeros(Float64, num_operators)

    completed = Set{Any}()
    queue = copy(all_cargo)

    current_time = 0.0

    while !isempty(queue)

        progress = false

        for idx in eachindex(queue)
            c = queue[idx]

            arr_time = arrival_dict[c]

            if arr_time > current_time # check if cargo have arrived, if it hasn't, proceed
                continue
            end


            blocked = any(dep ∉ completed for dep in V[c] if dep in queue) # check if the cargo is good to stow, or if it would block
            if blocked
                continue
            end

        
            op = argmin(busy_until)
            start_time = max(arr_time, busy_until[op], current_time)
            finish_time = start_time + handling_time

            busy_until[op] = finish_time
            current_time = minimum(busy_until)

            push!(completed, c)
            deleteat!(queue, idx)

            progress = true
            break
        end

        if !progress # when there is no more cargo to stow at current time
            next_arrival = minimum(arrival_dict[c] for c in queue) # see when the next cargo is arriving
            next_free = minimum(busy_until) # see when next tugmaster is free

            if next_arrival > current_time
                current_time = next_arrival
            else
                c = argmin([length(V[x]) for x in queue])
                c = queue[c]

                op = argmin(busy_until)
                start_time = max(arrival_dict[c], busy_until[op], current_time)
                finish_time = start_time + handling_time

                busy_until[op] = finish_time
                current_time = minimum(busy_until)

                push!(completed, c)
                deleteat!(queue, findfirst(==(c), queue))
            end
        end
    end

    return maximum(busy_until)
end