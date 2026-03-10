include(joinpath(pwd(), "src/deck_representation.jl"))

w,l = 8,13
unava = [
         ]

ramp = []

magnoliaMainstruct = Deck(w,l,unava, ramp)
magnoliaMainmat = create_deck(magnoliaMainstruct)