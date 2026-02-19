
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

#introduces parameter to weigh importance of minimizing shifts vs. minimizing waiting time. 
#a=1 all importance to shifts, a=0 all importance to arrical times
function pri_rules2(deck,cargo, a=0.5) 
    cargoDict = Dict()
    scoreList = []

    for (i,c) in enumerate(cargo)
        cargoDict["c$i"] = c
    end

    for (k,v) in cargoDict
        push!(scoreList, [k, a*(1/v.port) + (1-a)*v.arr])
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

