include(joinpath(pwd(), "src/deck_representation.jl"))

w,l = 7,10
unava = [[7 1],[7 2],[7 3],[7 8],[7 9],[7 10]]
ramp = [[7 4],[7 5],[7 6],[7 7]]

deckAstruct = Deck(w,l,unava, ramp)
deckAmat = create_deck(deckAstruct)
