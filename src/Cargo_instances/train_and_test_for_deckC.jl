using Random
include(joinpath(pwd(), "src/cargo_generation.jl"))
Random.seed!(4242)

trainsize = 20
test_size = 5

seedstrain = [rand(1:10000) for i in 1:trainsize]
seedstest = [rand(1:10000) for i in 1:test_size]

training_sets_240 = [genereate_cargo_structs(240,seed = i) for i in seedstrain]
test_sets_240 = [genereate_cargo_structs(240,seed = i) for i in seedstest]

seedstrain = [rand(1:10000) for i in 1:trainsize]
seedstest = [rand(1:10000) for i in 1:test_size]

training_sets_40_240 = [genereate_cargo_structs(40 + 10*i,seed = r) for (i,r) in enumerate(seedstrain)]
test_sets_40_240 = [genereate_cargo_structs(40 + 40*i,seed = r) for (i,r) in enumerate(seedstest)]