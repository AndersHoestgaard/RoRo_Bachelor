
include(joinpath(pwd(), "src/cargo_generation.jl"))

cargoC = genereate_cargo_structs(340,seed = 3754)

