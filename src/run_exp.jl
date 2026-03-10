t1 = time()
println("loading code...")
include("tests/min_shifts.jl")
include("Heuristics/loadback2front.jl")
include("Heuristics/priorityQ.jl")
include("Decks/DeckA.jl")
include("Decks/DeckB.jl")
include("Decks/DeckC.jl")
include("Cargo_instances/CargoA.jl")
include("Cargo_instances/CargoB.jl")
include("Cargo_instances/CargoC.jl")
include("Utils/visualization.jl")
include("tests/test1.jl")
include("tests/run_alns.jl")
include("cargo_generation.jl")
include("Heuristics/load_random.jl")
include("Heuristics/alns.jl")


println("alns...")
carg = genereate_cargo_structs(150,seed=2)

d,c = alns_hansen_fast(deckCmat, carg,init = pri_rules2,iterations = 5000, rho = 0.2)
println("alns normal...")
d,c = alns_hansen(deckCmat, carg,init = pri_rules2,iterations = 5000, rho = 0.2)




