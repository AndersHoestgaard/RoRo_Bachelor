include(joinpath(pwd(), "src/deck_representation.jl"))

# 8 rækker (lanes) x 27 kolonner (~10m per kolonne)
w, l = 8, 27

unava = [
    # Bov-taper (kolonne 1-2, hjørner)
    [1 1], [2 1], [7 1], [8 1],
    [1 2], [8 2],

    # Agter-taper (kolonne 26-27, hjørner)
    [1 26], [8 26],
    [1 27], [2 27], [7 27], [8 27],

    # Midterskibs obstruktion (maskinrum, ca. kolonne 7-10)
    [3 7], [4 7], [5 7], [6 7],
    [3 8], [4 8], [5 8], [6 8],
    [3 9], [4 9], [5 9], [6 9],
    [3 10], [4 10], [5 10], [6 10],
]

# Rampe på styrbord side (row 8), ca. 60% henne = kolonne 15-19
ramp = [[8 15], [8 16], [8 17], [8 18], [8 19]]

deckTorMstruct = Deck(w, l, unava, ramp)
deckTorMmat = create_deck(deckTorMstruct)