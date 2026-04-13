using Random
Random.seed!(4242)

trainsize = 20
test_size = 5

seedstrain = [rand(1:10000) for i in 1:trainsize]
seedstest = [rand(1:10000) for i in 1:test_size]

training_sets_240 = [genereate_cargo_structs(240,seed = i) for i in seedstrain]
test_sets_240 = [genereate_cargo_structs(240,seed = i) for i in seedstest]