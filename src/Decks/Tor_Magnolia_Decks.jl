include(joinpath(pwd(), "src/deck_representation.jl"))

w,l = 8,13
unava = [[1,1],[2,1],[3,1],[6,1],[7,1],[8,1],
         [1,2],[2,2],[7,2],[8,2],
         [1,3],[8,3],



         [3,7],[4,7],[5,7],[6,7],
         [3,8],[4,8],[5,8],[6,8],
         [3,9],[4,9],[5,9],[6,9],
         [3,10],[4,10],[5,10],[6,10],
         [3,11],[4,11],[5,11],[6,11],
         [4,12],[5,12]


         
         ]

ramp = [[2,13],[3,13],[4,13],[5,13],[6,13],[7,13]]

magnoliaMainstruct = Deck(w,l,unava, ramp)
magnoliaMainmat = create_deck(magnoliaMainstruct)

