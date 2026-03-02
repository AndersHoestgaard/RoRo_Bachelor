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

function destroy_random(deck;xi=0.2)
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
            push!(L,deck[i,j])
            deck[i,j] = 1
        end
    end
    return deck, L
end

function destroy_port(deck;xi=0.2)
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
            push!(L,deck[i,j])
            deck[i,j] = 1
        end
    end
    return deck, L
end

function destroy_shifting_cost(deck;xi=0.2)
    _,V = shortest_path_like_hansen(deck)
    h,w = size(deck)
    blockers = [[div(num[2], w)+1,num[2]%w +1] for num in V]
    n_selected_blockers = maximum([(xi/2)*length(blockers),1])
    selected_blockers = [popfirst!(shuffle!(blockers)) for n in 1:n_selected_blockers]
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
            push!(L, deck[i,j])
            deck[i,j] = 1
        end
    end
    return deck,L
end

# Repairers 
function repair_greedy(deck, cargo2place)  
    #This is basically the same as already implemented
    d,c = pri_rules2(deck,cargo2place) 
    return d,c
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

function repair_placement(deck, cargo)
    return ""

end

function repair_random(deck, cargo)
    return ""


end
A = [4 3 4 3 4;
     4 4 7 4 4;
     4 4 4 4 4;
     4 4 5 4 4;
     4 4 4 8 4;
     4 5 4 4 9]

#d, n = destroy_port(A, xi=1)
#shortest_path_like_hansen(A)



