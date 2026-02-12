include(joinpath(pwd(), "src/deck_representation.jl"))

w,l = 7,10
unava = [[7 1],[7 2],[7 3],[7 8],[7 9],[7 10],[5 5],[5 3],[1 1],[1 10],[2 4],[3 8]]
ramp = [[7 4],[7 5],[7 6],[7 7]]

deckBstruct = Deck(w,l,unava, ramp)
deckBmat = create_deck(deckBstruct)
