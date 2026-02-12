using Graphs, SimpleWeightedGraphs

function get_c_loc(deck,port=1) #Get location of cargo for port
    portid = port+2

    id_cargo = []
    for (i,row) in enumerate(eachrow(deck)) 
        for (j,slot) in enumerate(row)
            if slot == portid
                push!(id_cargo,[i,j])
    
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

function get_graph(deck) #Model deck as dir. weighted graph. 
    
    m, n = size(deck)
    g = SimpleWeightedDiGraph(m * n)
        
    for i in 1:m
        for j in 1:n
            
            # Skip empty slots
            if deck[i,j] == 0
                continue
            end
            
            current_node = (i-1)*n + j
            
            # --- NORTH ---
            if i > 1 && deck[i-1,j] != 0
                neighbor_node = (i-2)*n + j
                cost = deck[i-1,j] > 3 ? 1.0 : 0.0001
                add_edge!(g, current_node, neighbor_node, cost)
            end
            
            # --- WEST ---
            if j > 1 && deck[i,j-1] != 0
                neighbor_node = (i-1)*n + (j-1)
                cost = deck[i,j-1] > 3 ? 1.0 : 0.0001
                add_edge!(g, current_node, neighbor_node, cost)
            end

            # --- SOUTH ---
            if i < m && deck[i+1,j] != 0
                neighbor_node = i*n + j
                cost = deck[i+1,j] > 3 ? 1.0 : 0.0001
                add_edge!(g, current_node, neighbor_node, cost)
            end

            # --- EAST ---
            if j < n && deck[i,j+1] != 0
                neighbor_node = (i-1)*n + (j+1)
                cost = deck[i,j+1] > 3 ? 1.0 : 0.0001
                add_edge!(g, current_node, neighbor_node, cost)
            end
        end
    end
    
    return g
end

function shortest_path(deck) # Normal shortest path. 

    start_slots = get_c_loc(deck) 
    goal_slots = get_ramp_loc(deck) 
    m, n = size(deck) 
    results = [] 
    for (idx, start_pos) in enumerate(start_slots) 
        g = get_graph(deck)
        start_node = (start_pos[1]-1)*n + start_pos[2] 

        dsp = dijkstra_shortest_paths(g, start_node) 
        dists = dsp.dists 
        
        min_dist = Inf 
        best_goal = nothing 
        best_path = nothing 

        for goal_pos in goal_slots 
            goal_node = (goal_pos[1]-1)*n + goal_pos[2] 
            if dists[goal_node] < min_dist 
                min_dist = dists[goal_node] 
                best_goal = goal_pos 
                path = [] 
                current = goal_node 
                while current != start_node 
                    pushfirst!(path, current) 
                    current = dsp.parents[current] 
                    if current == 0 
                        break 
                    end 
                end 
                pushfirst!(path, start_node) 
                best_path = path 
            end 
        end 
        push!(results, (start_pos, best_goal, min_dist, best_path)) 
    end 
    return results 
end

function shortest_path_like_hansen(deck) # Shiortest path like the article by Hansen


    goal_slots = get_ramp_loc(deck)
    m, n = size(deck)
    start_slots = get_c_loc(deck)
    
    results = []
    V = Set{Tuple{Int,Int}}()   
    
    for (idx, start_pos) in enumerate(start_slots)
        g = get_graph(deck)
        start_node = (start_pos[1]-1)*n + start_pos[2]
        
        dsp = dijkstra_shortest_paths(g, start_node)
        dists = dsp.dists
        
        min_dist = Inf
        best_goal = nothing
        best_path = nothing
        
        for goal_pos in goal_slots
            goal_node = (goal_pos[1]-1)*n + goal_pos[2]
            
            if dists[goal_node] < min_dist
                min_dist = dists[goal_node]
                best_goal = goal_pos
                
                path = []
                current = goal_node
                
                while current != start_node
                    pushfirst!(path, current)
                    current = dsp.parents[current]
                    if current == 0
                        break
                    end
                end
                
                pushfirst!(path, start_node)
                best_path = path
            end
        end
        
        
        if best_path !== nothing
            for i in 1:length(best_path)-1
                u = best_path[i]
                v = best_path[i+1]
                
                w = weights(g)[u, v]
                
                if isapprox(w, 1.0; atol=1e-9)
                    push!(V, (u,v))
                    
                    
                    add_edge!(g, u, v, 0.0001)
                end
            end
        end
    
        
        push!(results, (start_pos, best_goal, min_dist, best_path))
    end
    
    return results, V
end

function min_shifts(deck)
    return length(shortest_path_like_hansen(deck)[2])
end
