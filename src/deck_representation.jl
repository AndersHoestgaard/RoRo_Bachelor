
struct Deck
    width::Int32
    length::Int32
    unava::Array{Any}
    ramp::Array{Any}
end

function create_deck(deck)
    w,l = deck.width, deck.length
    unava = deck.unava 
    ramp = deck.ramp

    outline = ones(Int,w,l)

    for coord in unava 
        x,y = coord 
        outline[x,y] = 0
    end

    for r in ramp 
        x,y = r 
        if outline[x,y] != 0
            outline[x,y] = 2
        end
    end     
    return outline
end

