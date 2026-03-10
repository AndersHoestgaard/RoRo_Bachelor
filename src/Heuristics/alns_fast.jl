using Random
include(joinpath(pwd(),"src/tests/min_shifts.jl"))
include(joinpath(pwd(),"src/Heuristics/priorityQ.jl"))

# Optimized to be faster by Grok
# EDIT: I have tested and it pretty much the same as prev. implemented alns
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

function destroy_neighborf(deck, cargo_on; xi=0.2)
    deck = copy(deck)
    cargo_on = copy(cargo_on)
    h, w = size(deck)
    
    # Precompute cargo positions
    cargo_positions = Tuple.(findall(x -> x > 2, deck))
    n_cargo = length(cargo_positions)
    
    # Find boundary cargo positions
    Lloc = []
    for pos in cargo_positions
        i, j = pos
        slot = deck[i, j]
        neighbors = []
        if i > 1; push!(neighbors, deck[i-1, j]); end
        if j > 1; push!(neighbors, deck[i, j-1]); end
        if i < h; push!(neighbors, deck[i+1, j]); end
        if j < w; push!(neighbors, deck[i, j+1]); end
        if !(slot in neighbors)
            push!(Lloc, pos)
        end
    end
    
    shuffle!(Lloc)
    target = ceil(Int, xi * n_cargo)
    L = []
    for pos in Lloc[1:min(target, length(Lloc))]
        i, j = pos
        push!(L, cargo_on[i, j])
        cargo_on[i, j] = nothing
        deck[i, j] = 1
    end
    
    return deck, L, cargo_on
end

function destroy_areaf(deck, cargo_on; xi=0.1)
    deck = copy(deck)
    cargo_on = copy(cargo_on)

    h, w = size(deck)

    n_cargo = count(!isnothing, cargo_on)
    cargo_positions = Tuple.(findall(!isnothing, cargo_on))
    target = ceil(Int, n_cargo * xi)
    


    cargo2place = Any[]
    start_loc = rand(cargo_positions)
    start_i, start_j = start_loc
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

function destroy_randomf(deck, cargo_on; xi=0.2)
    deck = copy(deck)
    cargo_on = copy(cargo_on)
    h, w = size(deck)
    
    cargo_positions = Tuple.(findall(x -> x > 2, deck))
    n_cargo = length(cargo_positions)
    target = ceil(Int, xi * n_cargo)
    
    shuffle!(cargo_positions)
    L = []
    for pos in cargo_positions[1:min(target, length(cargo_positions))]
        i, j = pos
        push!(L, cargo_on[i, j])
        deck[i, j] = 1
        cargo_on[i, j] = nothing
    end
    
    return deck, L, cargo_on
end

function destroy_portf(deck, cargo_on; xi=0.2)
    # Assuming A is defined somewhere, but in code it's unique(A), probably a global or from include
    # For now, assume ports = unique(deck[deck .> 2])
    ports = unique(deck[deck .> 2])
    port2rem = rand(ports)
    
    deck = copy(deck)
    cargo_on = copy(cargo_on)
    
    cargo_positions = Tuple.(findall(x -> x == port2rem, deck))
    n_cargo = length(cargo_positions)
    target = ceil(Int, xi * n_cargo)
    
    shuffle!(cargo_positions)
    L = []
    for pos in cargo_positions[1:min(target, length(cargo_positions))]
        i, j = pos
        push!(L, cargo_on[i, j])
        deck[i, j] = 1
        cargo_on[i, j] = nothing
    end
    
    return deck, L, cargo_on
end

function destroy_shifting_costf(deck, cargo_on; xi=0.2)
    deck = copy(deck)
    cargo_on = copy(cargo_on)
    _, V = shortest_path_like_hansen(deck)
    h, w = size(deck)
    
    cargo_positions = Tuple.(findall(x -> x > 2, deck))
    n_cargo = length(cargo_positions)
    
    if isempty(V)
        # Randomly sample cargo positions as blockers
        n_selected_blockers = max(1, round(Int, xi * n_cargo / 2))
        n_selected_blockers = min(n_selected_blockers, length(cargo_positions))
        selected_blockers = shuffle!(copy(cargo_positions))[1:n_selected_blockers]
    else
        blockers = [(div(num[2], w) + 1, num[2] % w + 1) for num in V]
        n_selected_blockers = max(1, round(Int, xi / 2 * length(blockers)))
        selected_blockers = shuffle!(blockers)[1:min(n_selected_blockers, length(blockers))]
    end
    
    rad = length(selected_blockers)
    Lloc = Set()  # Use Set to avoid duplicates
    for slot in selected_blockers
        push!(Lloc, slot)
        i, j = slot
        for skridt in 1:rad
            if i > 1
                push!(Lloc, (i-1, j))
                if j > 1; push!(Lloc, (i-1, j-1)); end
                if j < w; push!(Lloc, (i-1, j+1)); end
            end
            if i < h
                push!(Lloc, (i+1, j))
                if j > 1; push!(Lloc, (i+1, j-1)); end
                if j < w; push!(Lloc, (i+1, j+1)); end
            end
            if j > 1; push!(Lloc, (i, j-1)); end
            if j < w; push!(Lloc, (i, j+1)); end
        end
    end
    
    L = []
    for loc in Lloc
        i, j = loc
        if i >= 1 && i <= h && j >= 1 && j <= w && deck[i, j] > 2
            push!(L, cargo_on[i, j])
            deck[i, j] = 1
            cargo_on[i, j] = nothing
        end
    end
    return deck, L, cargo_on
end

# Repairers 
function repair_greedyf(deck, cargo2place, cargo_on)  
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

function repair_neighborf(deck, cargo2place, cargo_on)
    deck = copy(deck)
    cargo_on = copy(cargo_on)
    cargo2place = copy(cargo2place)  # To modify
    
    h, w = size(deck)
    
    for i in 1:h
        for j in 1:w
            if deck[i, j] == 1 && !isempty(cargo2place)
                placed = false
                shuffle!(cargo2place)
                for k in 1:length(cargo2place)
                    cargo = cargo2place[k]
                    if cargo.port in get_neighbors(deck, i, j)
                        cargo_on[i, j] = cargo
                        deck[i, j] = cargo.port
                        deleteat!(cargo2place, k)
                        placed = true
                        break
                    end
                end
                if !placed
                    cargo = popfirst!(cargo2place)
                    cargo_on[i, j] = cargo
                    deck[i, j] = cargo.port
                end
            end
        end
    end
    
    return deck, cargo_on
end

function repair_neighbor_randf(deck, cargo2place, cargo_on)
    deck = copy(deck)
    cargo_on = copy(cargo_on)
    cargo2place = copy(cargo2place)
    
    h, w = size(deck)
    
    locs = Tuple.(findall(x -> x == 1, deck))
    shuffle!(locs)
    shuffle!(cargo2place)
    
    for loc in locs
        i, j = loc
        if !isempty(cargo2place)
            placed = false
            for k in 1:length(cargo2place)
                cargo = cargo2place[k]
                if cargo.port in get_neighbors(deck, i, j)
                    cargo_on[i, j] = cargo
                    deck[i, j] = cargo.port
                    deleteat!(cargo2place, k)
                    placed = true
                    break
                end
            end
            if !placed
                cargo = popfirst!(cargo2place)
                cargo_on[i, j] = cargo
                deck[i, j] = cargo.port
            end
        end
    end
    
    return deck, cargo_on
end

function repair_placementf(deck, cargo2place,cargo_on)
    deck = copy(deck)
    g_deck = copy(deck)
    g_deck[g_deck .> 2] .= 1
    m,n = size(deck)
    free_cart = findall(x-> x==1, g_deck)
    free = Tuple.(free_cart)
    
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
        i,j = loc[1]

        if deck[i,j] == 1 && isnothing(cargo_on[i,j] )
            c = popfirst!(cargo2place)
            deck[i,j] = c.port
            cargo_on[i,j] = c
        end

    end
    
    return deck, cargo_on

end

function repair_randomf(deck, cargo2place, cargo_on)
    if isempty(cargo2place)
        @warn "Repair operator received complete deck"
        return deck, cargo_on
    end
    deck = copy(deck)
    cargo_on = copy(cargo_on)
    cargo2place = copy(cargo2place)
    
    locs = Tuple.(findall(x -> x == 1, deck))
    shuffle!(locs)
    shuffle!(cargo2place)
    
    n_to_place = min(length(locs), length(cargo2place))
    for i in 1:n_to_place
        pos = locs[i]
        cargo = cargo2place[i]
        deck[pos[1], pos[2]] = cargo.port
        cargo_on[pos[1], pos[2]] = cargo
    end
    
    deleteat!(cargo2place, 1:n_to_place)
    return deck, cargo_on
end




