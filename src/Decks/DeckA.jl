include(joinpath(pwd(), "src/deck_representation.jl"))

w,l = 7,10
unava = [[1 10],[2 10],[6 10],[7 10]]
ramp = [[3 10],[4 10],[5 10]]

deckAstruct = Deck(w,l,unava, ramp)
deckAmat = create_deck(deckAstruct)
