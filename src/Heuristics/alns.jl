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

function destroy_area(deck;xi=0.2)
    ## Wait until we get the actual outline
    return ""
end

function destroy_random(deck, cargo_on;xi=0.2)
    deck = copy(deck)
    h,w = size(deck)

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
    port2rem = rand(unique(A)[unique(A).>2])

    deck = copy(deck)
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
    h,w = size(deck)

    for (i,row) in enumerate(eachrow(deck))
        for (j,slot) in enumerate(row)
            if slot == 1
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

function repair_placement(deck, cargo2place,cargo_on)
    return ""

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




