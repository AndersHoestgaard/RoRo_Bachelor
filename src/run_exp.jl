println("loading code...")
include("tests/min_shifts.jl")
include("tests/run_tests.jl")
include("Heuristics/loadback2front.jl")
include("Heuristics/alns_arrival_time.jl")
include("Heuristics/priorityQ.jl")
include("Decks/DeckA.jl")
include("Decks/DeckB.jl")
include("Decks/DeckC.jl")
include("Decks/Tor_Magnolia_Decks.jl")
include("Cargo_instances/train_and_test_for_deckC.jl")
include("Cargo_instances/train_and_test_for_deckB.jl")
include("Cargo_instances/train_and_test_for_deckA.jl")
include("Cargo_instances/toy_inst_deckA.jl")
include("Cargo_instances/CargoB.jl")
include("Cargo_instances/CargoC.jl")
include("Utils/visualization.jl")
include("Utils/param_tuning.jl")
include("tests/convergence_analysis.jl")
include("tests/run_alns.jl")
include("cargo_generation.jl")
include("Heuristics/load_random.jl")

include("Heuristics/grasp.jl")
println("alns...")














