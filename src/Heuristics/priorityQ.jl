
function pri_rules1(deck,cargo)
    cargoDict = Dict()
    scoreList = []

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
        placed = false
        for (i,row) in enumerate(eachrow(deck))
            if placed
                continue
            end
            for (j,slot) in enumerate(row)
                if placed
                continue
                end
                if slot == 1
                    deck[i,j] = cport
                    placed = true
                end
            
            end
            
        end
    end
    return deck
end

function pri_rules2(deck,cargo; a=0.5) 
    cargoDict = Dict()
    scoreList = []
    deck = copy(deck)
    cargo = copy(cargo)
    h,w = size(deck)
    for (i,c) in enumerate(cargo)
        cargoDict["c$i"] = c
    end

    for (k,v) in cargoDict
        push!(scoreList, [k, a*(1/v.port) + (1-a)*v.arr])
    end
    scoreList = sort(scoreList, by = x -> x[2])
    cargo_on = Matrix{Any}(nothing, h, w)
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

