include(joinpath(pwd(), "src/Heuristics/alns.jl"))
include("obj_func.jl")


function simulate_alns_simple(deck, cargo; init = pri_rules2, destroyer = destroy_random, repairer=repair_random, n_sim=1000, xi=0.2 )
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


function simulate_alns(deck, cargo; init = pri_rules2, destroyer = destroy_random, repairer=repair_random, n_sim=1000, xi=0.2, acceptance_prob=0.1)
    ob_vals = []
    best_deck, best_cargo = init(deck, cargo)
    best_val = evaluate_sol(best_deck, best_cargo)
    
    current_deck = copy(best_deck)
    current_cargo = copy(best_cargo)
    current_val = best_val

    for i in 1:n_sim
        destroyed_deck, cargo2place, destroyed_cargo_on = destroyer(current_deck, current_cargo, xi=xi)
        repaired_deck, repaired_cargo_on = repairer(destroyed_deck, cargo2place, destroyed_cargo_on)
        
        new_val = evaluate_sol(repaired_deck, repaired_cargo_on)

        if new_val > best_val
            best_deck = repaired_deck
            best_cargo = repaired_cargo_on
            best_val = new_val
            current_deck = copy(repaired_deck)
            current_cargo = copy(repaired_cargo_on)
            current_val = new_val
        elseif new_val > current_val || rand() < acceptance_prob
            current_deck = repaired_deck
            current_cargo = repaired_cargo_on
            current_val = new_val
        end
        
        push!(ob_vals, best_val)
    end
    return best_deck, ob_vals
end