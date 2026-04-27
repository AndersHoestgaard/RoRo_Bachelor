t1 = time()
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
include("Cargo_instances/CargoB.jl")
include("Cargo_instances/CargoC.jl")
include("Utils/visualization.jl")
include("Utils/param_tuning.jl")
include("tests/convergence_analysis.jl")
include("tests/run_alns.jl")
include("cargo_generation.jl")
include("Heuristics/load_random.jl")
include("Heuristics/alns.jl")
include("Heuristics/grasp.jl")
println("alns...")

run_alns_test_on_instance(deckAmat,cargo_a_75_6, patience = 5000) 
#d,c,h,_ = alns_hansen_basket(deckAmat,cargo_a_75_6[18],print_status=false,early_stop_thres=3000,
#priority=[0.6,0.35,0.05],
#grasp_its=2000,
#)
#println(wait_time(d,c)-perfect_wait_time(d,c))

#println(min_shift_all_cargo_work(d))


#plot_deck(d)








