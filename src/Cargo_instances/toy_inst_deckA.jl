using Random
include(joinpath(pwd(), "src/cargo_generation.jl"))
Random.seed!(4242)

trainsize = 20



# 20
seedstrain = [rand(1:10000) for i in 1:trainsize]
deckA20 = [genereate_cargo_structs(floor(Int,20),seed = i,num_ports = 6) for i in seedstrain]
