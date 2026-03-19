using Random
include(joinpath(pwd(),"src/tests/min_shifts.jl"))
include(joinpath(pwd(),"src/Heuristics/priorityQ.jl"))

# Destroy operators
function get_neighbors(deck,i,j) # Helper func.for some of the neighbor funcs. 
    neighs = []
    h,w = size(deck)

    if i != 1
        push!(neighs, deck[i-1,j])
    end
    if j != 1
        push!(neighs, deck[i,j-1])
    end 
    if i!=h 
        push!(neighs, deck[i+1,j])
    end
    if j!=w
        push!(neighs, deck[i,j+1])
    end
    return neighs
end

function destroy_neighbor(deck, cargo_on;xi=0.2)
    deck = copy(deck)
    cargo_on = copy(cargo_on)
    h,w = size(deck)
    
    
    L = []
    Lloc = []

    n_cargo = 0
    for (i, row) in enumerate(eachrow(deck))
        for (j, slot) in enumerate(row)
            if slot > 2
                n_cargo +=1
            end
        end
    end

    
    for (i, row) in enumerate(eachrow(deck))
        for (j, slot) in enumerate(row)
            if slot > 2
                if !(slot in get_neighbors(deck,i,j))
                    push!(Lloc,[i,j])
                end
            end

        end
    end

    

    for (count, loc) in enumerate(shuffle!(Lloc))
        if count > xi*n_cargo
            return deck,L, cargo_on
        else 
            push!(L, cargo_on[loc[1], loc[2]])
            cargo_on[loc[1], loc[2]] = nothing
            deck[loc[1], loc[2]] = 1
        end
    end

    return deck, L, cargo_on
end

function destroy_area(deck, cargo_on; xi=0.1)
    deck = copy(deck)
    cargo_on = copy(cargo_on)

    h, w = size(deck)

    n_cargo = count(!isnothing, cargo_on)
    cargo_positions = findall(!isnothing, cargo_on)
    target = ceil(Int, n_cargo * xi)
    


    cargo2place = Any[]
    start_loc = rand(cargo_positions)
    start_i, start_j = start_loc[1], start_loc[2]
    area_height = 0
    area_width = 0

    while length(cargo2place) < target && area_height ≤ h && area_width ≤ w

        # Expand crater area
        for i in start_i:(start_i + area_height)
            for j in start_j:(start_j + area_width)

                if i < 1 || i > h || j < 1 || j > w
                    continue
                end

                if deck[i, j] > 2 && !isnothing(cargo_on[i, j])
                    push!(cargo2place, cargo_on[i, j])
                    deck[i, j] = 1
                    cargo_on[i, j] = nothing
                end

                if length(cargo2place) >= target
                    break
                end
            end
                
            if length(cargo2place) >= target
                break
            end
            
        end

        # Randomly expand crater
        if rand() > 0.5
            area_height += 1
        else
            area_width += 1
        end
        
    end

    return deck, cargo2place, cargo_on
end

function destroy_random(deck, cargo_on;xi=0.2)
    deck = copy(deck)
    h,w = size(deck)
    cargo_on = copy(cargo_on)

    n_cargo = 0
    for (i, row) in enumerate(eachrow(deck))
        for (j, slot) in enumerate(row)
            if slot > 2
                n_cargo +=1
            end
        end
    end

    L = []
    while length(L) < xi*n_cargo
        i = rand(1:h)
        j = rand(1:w)

        if deck[i,j] > 2
            push!(L,cargo_on[i,j])
            deck[i,j] = 1
            cargo_on[i,j] = nothing
        end
    end
    return deck, L, cargo_on
end

function destroy_port(deck, cargo_on;xi=0.2)
    port2rem = rand(unique(deck)[unique(deck).>2])

    deck = copy(deck)
    cargo_on = copy(cargo_on)

    h,w = size(deck)

    n_cargo = 0
    for (i, row) in enumerate(eachrow(deck))
        for (j, slot) in enumerate(row)
            if slot == port2rem
                n_cargo +=1
            end
        end
    end

    L = []
    while length(L) < xi*n_cargo 
        i = rand(1:h)
        j = rand(1:w)

        if deck[i,j] == port2rem
            push!(L,cargo_on[i,j])
            deck[i,j] = 1
            cargo_on[i,j] = nothing
        end
    end
    return deck, L, cargo_on
end

function destroy_shifting_cost(deck, cargo_on;xi=0.2)
    deck = copy(deck)
    cargo_on = copy(cargo_on)
    _,V = shortest_path_like_hansen(deck)
    h,w = size(deck)
    
    n_cargo = 0
    for (i, row) in enumerate(eachrow(deck))
        for (j, slot) in enumerate(row)
            if slot > 2
                n_cargo +=1
            end
        end
    end
    
    if isempty(V)
        # Randomly sample cargo positions as blockers
        cargo_positions = []
        for i in 1:h
            for j in 1:w
                if deck[i,j] > 2
                    push!(cargo_positions, [i,j])
                end
            end
        end
        n_selected_blockers = max(1, round(Int, xi * n_cargo / 2))
        n_selected_blockers = min(n_selected_blockers, length(cargo_positions))
        selected_blockers = shuffle!(cargo_positions)[1:n_selected_blockers]
    else
        blockers = [[div(num[2], w)+1,num[2]%w +1] for num in V]
        n_selected_blockers = maximum([(xi/2)*length(blockers),1])
        selected_blockers = [popfirst!(shuffle!(blockers)) for n in 1:n_selected_blockers]
    end
    
    rad = length(selected_blockers)
    Lloc =[]
    L = []

    for slot in selected_blockers
        push!(Lloc,slot)
        (i,j) = slot
        for skridt in 1:rad
            if i !=1
                push!(Lloc,[i-1, j])
                if j != 1
                    push!(Lloc,[i-1, j-1])
                end
                if j != w
                    push!(Lloc,[i-1, j+1])
                end
            end 
            if i != h
                push!(Lloc,[i+1, j])
                if j != 1
                    push!(Lloc,[i+1, j-1])
                end
                if j != w
                    push!(Lloc,[i+1, j+1])
                end
            end 
            if j !=1
                push!(Lloc,[i, j-1])
            end 
            if j != w
                push!(Lloc,[i, j+1])
            end 
        end
        
    end

    for loc in Lloc
        (i,j) = loc
        if deck[i,j ] > 2
            push!(L, cargo_on[i,j])
            deck[i,j] = 1
            cargo_on[i,j] = nothing
        end
    end
    return deck,L, cargo_on
end

# Repairers 
function repair_greedy(deck, cargo2place, cargo_on)  
    #This is basically the same as pri_rules

    cargoDict = Dict()
    scoreList = []
    deck = copy(deck)
    cargo = copy(cargo2place)
    h,w = size(deck)

    for (i,c) in enumerate(cargo)
        cargoDict["c$i"] = c
    end

    for (k,v) in cargoDict
        push!(scoreList, [k, 1/v.port + v.arr])
    end

    scoreList = sort(scoreList, by = x -> x[2])
    
    for score in scoreList
        (id,_) = score
        cport = cargoDict[id].port
        carg = cargoDict[id]
        placed = false
        for (j,col) in enumerate(eachcol(deck))
            if placed
                continue
            end
            for (i,slot) in enumerate(col)
                if placed
                    continue
                end
                if slot == 1
                    deck[i,j] = cport
                    placed = true
                    cargo_on[i,j] = carg
                end
            
            end
            
        end
    end
    return deck, cargo_on
end

function repair_neighbor(deck, cargo2place,cargo_on)
    deck = copy(deck)
    cargo_on = copy(cargo_on)


    h,w = size(deck)

    for (i,row) in enumerate(eachrow(deck))
        for (j,slot) in enumerate(row)

            if slot == 1 && !isempty(cargo2place)
                placed = false

                for cargo in shuffle!(copy(cargo2place))
                    if !placed
                        if cargo.port in get_neighbors(deck,i,j)
                            cargo_on[i,j] = cargo
                            deck[i,j] = cargo.port
                            filter!(x->x !== cargo,cargo2place)
                            placed = true

                        end
                    end
                end
                if !placed 
                    c2p = popfirst!(shuffle!(cargo2place))
                    cargo_on[i,j] = c2p
                    deck[i,j] = c2p.port
                    filter!(x->x !== c2p,cargo2place)
                end
            end
        end 
    end
        
    return deck,cargo_on
end

function repair_neighbor_rand(deck, cargo2place,cargo_on)
    deck = copy(deck)
    cargo_on = copy(cargo_on)


    h,w = size(deck)

    locs = []
    for (i,row) in enumerate(eachrow(deck))
        for (j,slot) in enumerate(row)
            if slot == 1
                push!(locs, [i,j])
            end
        end
    end

    shuffle!(locs)
    for loc in locs
        (i,j) = loc[1], loc[2]
        slot = deck[i,j]

        if !isempty(cargo2place)
            placed = false

            for cargo in shuffle!(copy(cargo2place))
                if !placed
                    if cargo.port in get_neighbors(deck,i,j)
                        cargo_on[i,j] = cargo
                        deck[i,j] = cargo.port
                        filter!(x->x !== cargo,cargo2place)
                        placed = true

                    end
                end
            end

        end
    end

    if !isempty(cargo2place)
        for (i,row) in enumerate(eachrow(deck))
            for (j,slot) in enumerate(row)
                if slot == 1 &&!isempty(cargo2place)
                    c = popfirst!(cargo2place)
                    cargo_on[i,j] = c
                    deck[i,j] = c.port
                    filter!(x->x !== c,cargo2place)
                end
            end    
        end
    end

    return deck,cargo_on
end

function repair_placement(deck, cargo2place,cargo_on)
    deck = copy(deck)
    g_deck = copy(deck)
    g_deck[g_deck .> 2] .= 1
    m,n = size(deck)
    free_cart = findall(x-> x==1, g_deck)
    free = [(c[1],c[2]) for c in free_cart]
    
    g = get_graph(g_deck)
    goal_slots = get_ramp_loc(g_deck)
    goal_pos = [(loc[1]-1)*n + loc[2] for loc in goal_slots]

    furthest_locs = []
    for loc in free
        pos  = (loc[1]-1)*n + loc[2]
        dsp = dijkstra_shortest_paths(g, pos) 

        dis = minimum([dsp.dists[i] for i in goal_pos])
        push!(furthest_locs,[loc,dis])
    end
    sort!(furthest_locs, by = x -> x[2],rev=true)
    sort!(cargo2place, by = x->x.port)
    
    for loc in furthest_locs
        if isempty(cargo2place)
            return deck, cargo_on
        end
        i,j = loc[1][1], loc[1][2]

        if deck[i,j] == 1 && isnothing(cargo_on[i,j] )
            c = popfirst!(cargo2place)
            deck[i,j] = c.port
            cargo_on[i,j] = c
        end

    end
    
    return deck, cargo_on

end

function repair_random(deck, cargo2place, cargo_on)
    if isempty(cargo2place)
        @warn "Repair operator received complete deck"
        return deck, cargo_on
    end
    deck = copy(deck)
    h,w = size(deck)

    locs = []
    for (i,row) in enumerate(eachrow(deck))
        for (j,slot) in enumerate(row)
            if slot == 1
                push!(locs, [i,j])
            end
        end
    end

    shuffle!(locs)

    n_to_place = min(length(locs), length(cargo2place))
    for i in 1:n_to_place
        loc = locs[i]
        c2p = cargo2place[i]
        deck[loc[1], loc[2]] = c2p.port
        cargo_on[loc[1], loc[2]] = c2p
    end

    deleteat!(cargo2place, 1:n_to_place)
    return deck,cargo_on
end




