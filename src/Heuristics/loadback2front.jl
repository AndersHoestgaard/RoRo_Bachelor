include(joinpath(pwd(), "ROROstowage/src/Cargo_instances/CargoA.jl"))
include(joinpath(pwd(), "ROROstowage/src/Cargo_instances/CargoB.jl"))
include(joinpath(pwd(), "ROROstowage/src/Decks/DeckA.jl"))
include(joinpath(pwd(), "ROROstowage/src/Decks/DeckB.jl"))
include(joinpath(pwd(), "ROROstowage/src/deck_representation.jl"))


function load_back2front_random(cargo, deck)
    deckmat = create_deck(deck)
    ncargo = length(cargo)

    
    for (i,row) in enumerate(eachrow(deckmat))
        for (j,slot) in enumerate(row)
            if slot == 1
                if isempty(cargo) 
                    return deckmat
                
                else
                deckmat[i, j] = pop!(cargo).port
                end
                
            end
            
        end
    end

    
end

function load_back2front_sorted(cargo, deck)
    deckmat = create_deck(deck)
    
    getport(c) = c.port
    sortcargo = sort(cargo, by=getport)

    for (i,row) in enumerate(eachrow(deckmat))
        for (j,slot) in enumerate(row)
            if slot == 1
                if isempty(sortcargo) 
                    return deckmat
                
                else
                deckmat[i, j] = pop!(sortcargo).port
                end
                
            end
            
        end
    end
end
