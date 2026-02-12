
include(joinpath(pwd(), "src/cargo_generation.jl"))
using Random
Random.seed!(4808)
cargoB = genereate_cargo_structs(48)

