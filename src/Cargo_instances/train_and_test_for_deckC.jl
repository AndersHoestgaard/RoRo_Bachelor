using Random
include(joinpath(pwd(), "src/cargo_generation.jl"))
Random.seed!(4242)

trainsize = 20
test_size = 5

legal_cap = 295

# 90%, 6 ports
seedstrain = [rand(1:10000) for i in 1:trainsize]
cargo_c_90_6 = [genereate_cargo_structs(floor(Int,legal_cap*0.9),seed = i,num_ports = 6) for i in seedstrain]

# 90%, 8 ports
seedstrain = [rand(1:10000) for i in 1:trainsize]
cargo_c_90_8 = [genereate_cargo_structs(floor(Int,legal_cap*0.9),seed = i,num_ports = 8) for i in seedstrain]

# 75%, 6 ports
seedstrain = [rand(1:10000) for i in 1:trainsize]
cargo_c_75_6 = [genereate_cargo_structs(floor(Int,legal_cap*0.75),seed = i,num_ports = 6) for i in seedstrain]

# 75%, 8 ports
seedstrain = [rand(1:10000) for i in 1:trainsize]
cargo_c_75_8 = [genereate_cargo_structs(floor(Int,legal_cap*0.75),seed = i,num_ports = 8) for i in seedstrain]



