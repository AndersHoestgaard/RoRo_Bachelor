
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

dstruct = Deck(7,10,[[1 1],[1 2],[2 1],[7 1],[7 2],[7 3],[7 8],[7 9],[7 10]], [[7 4],[7 5],[7 6],[7 7]])
dmat = create_deck(dstruct)
