using Random
include(joinpath(pwd(), "src/cargo_generation.jl"))
Random.seed!(4242)

trainsize = 20
test_size = 5

legal_cap = 295

# 90%
seedstrain = [rand(1:10000) for i in 1:trainsize]

cargo_c_90 = [genereate_cargo_structs(floor(Int,legal_cap*0.9),seed = i) for i in seedstrain]

# 75%
seedstrain = [rand(1:10000) for i in 1:trainsize]
cargo_c_75 = [genereate_cargo_structs(floor(Int,legal_cap*0.75),seed = i) for i in seedstrain]

# 60%
seedstrain = [rand(1:10000) for i in 1:trainsize]
cargo_c_60 = [genereate_cargo_structs(floor(Int,legal_cap*0.6),seed = i) for i in seedstrain]

# 45%
seedstrain = [rand(1:10000) for i in 1:trainsize]
cargo_c_45 = [genereate_cargo_structs(floor(Int,legal_cap*0.45),seed = i) for i in seedstrain]

# 30%
seedstrain = [rand(1:10000) for i in 1:trainsize]
cargo_c_30 = [genereate_cargo_structs(floor(Int,legal_cap*0.30),seed = i) for i in seedstrain]

# 20%
seedstrain = [rand(1:10000) for i in 1:trainsize]
cargo_c_20 = [genereate_cargo_structs(floor(Int,legal_cap*0.20),seed = i) for i in seedstrain]
