
function load_random(deck, cargo)
    deck=copy(deck)
    cargo=copy(cargo)
    h,w = size(deck)
    cargo_on = Matrix{Any}(nothing, h, w)
    while !isempty(cargo) && 1 in deck
        i = rand(1:h)
        j = rand(1:w)
        if deck[i,j] == 1
            
            current_cargo = popfirst!(cargo)
            
            deck[i,j] = current_cargo.port
            cargo_on[i,j] = current_cargo

        end
    end

    return deck, cargo_on
end


