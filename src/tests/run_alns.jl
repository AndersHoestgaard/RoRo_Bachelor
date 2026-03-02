include(joinpath(pwd(), "src/Heuristics/alns.jl"))
include("obj_func.jl")


function simulate_alns(deck, cargo; init = pri_rules2, destroyer = destroy_random, repairer=repair_random, n_sim=1000, xi=0.2 )
    ob_vals = []
    best_deck, best_cargo = init(deck,cargo)
    best_val = evaluate_sol(best_deck,best_cargo)

    for i in 1:n_sim
        destroyed_deck, cargo2place, destroyed_cargo_on = destroyer(best_deck, best_cargo,xi=xi)
        repaired_deck, repaired_cargo_on = repairer(destroyed_deck,cargo2place,destroyed_cargo_on)
        
        eval = evaluate_sol(repaired_deck, repaired_cargo_on)

        if eval> best_val
            best_deck = repaired_deck
            best_cargo = repaired_cargo_on
            best_val = eval
            
        end
        push!(ob_vals,best_val)

    end
    return best_deck, ob_vals
end