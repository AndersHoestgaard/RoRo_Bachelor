using Random
include(joinpath(pwd(), "src/cargo_generation.jl"))
Random.seed!(4242)

trainsize = 20
test_size = 5

legal_cap = 132
mean_int_arr = 4

# 90%, 6 ports
seedstrain = [rand(1:10000) for i in 1:trainsize]
cargo_c2_90_6 = [genereate_cargo_structs(floor(Int,legal_cap*0.9),seed = i,num_ports = 6,mean_minutes = mean_int_arr) for i in seedstrain]

# 90%, 8 ports
seedstrain = [rand(1:10000) for i in 1:trainsize]
cargo_c2_90_8 = [genereate_cargo_structs(floor(Int,legal_cap*0.9),seed = i,num_ports = 8,mean_minutes = mean_int_arr) for i in seedstrain]

# 75%, 6 ports
seedstrain = [rand(1:10000) for i in 1:trainsize]
cargo_c2_75_6 = [genereate_cargo_structs(floor(Int,legal_cap*0.75),seed = i,num_ports = 6,mean_minutes = mean_int_arr) for i in seedstrain]

# 75%, 8 ports
seedstrain = [rand(1:10000) for i in 1:trainsize]
cargo_c2_75_8 = [genereate_cargo_structs(floor(Int,legal_cap*0.75),seed = i,num_ports = 8,mean_minutes = mean_int_arr) for i in seedstrain]



