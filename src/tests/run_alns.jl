include(joinpath(pwd(), "src/Heuristics/alns.jl"))
include(joinpath(pwd(), "src/Heuristics/alns_fast.jl"))

include("obj_func.jl")

using StatsBase: sample, Weights


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

#from chatgpt:
function alns_hansen(deck, cargo;
        destroy_ops = [destroy_neighbor, destroy_area, destroy_port, destroy_random, destroy_shifting_cost],
        repair_ops = [repair_greedy, repair_neighbor_rand,repair_placement, repair_random],
        init = load_random,
        iterations = 10000,
        time_lim = 10000,
        segment = 100,
        rho = 0.1)

    t1 = time()
    sig1, sig2, sig3 = 33, 9, 3

    nd = length(destroy_ops)
    nr = length(repair_ops)

    w_d = ones(nd)
    w_r = ones(nr)

    score_d = zeros(nd)
    score_r = zeros(nr)

    use_d = zeros(nd)
    use_r = zeros(nr)

    best_deck, best_cargo = init(deck, cargo)
    best_val = evaluate_sol(best_deck, best_cargo)

    current_deck = copy(best_deck)
    current_cargo = copy(best_cargo)
    current_val = best_val

    history = []
    its = 0
    for it in 1:iterations
        its = it
        timespent = time() -t1
        if timespent > time_lim
            print("ran $it iterations and $timespent seconds")
            return best_deck, history
        end
        d = sample(1:length(destroy_ops), Weights(w_d))
        r = sample(1:length(repair_ops),  Weights(w_r))

        destroy = destroy_ops[d]
        repair = repair_ops[r]
        use_d[d] += 1
        use_r[r] += 1

        destroyed_deck, cargo2place, destroyed_cargo =
            destroy(current_deck, current_cargo)

        new_deck, new_cargo =
            repair(destroyed_deck, cargo2place, destroyed_cargo)

        new_val = evaluate_sol(new_deck, new_cargo)

        accepted = false

        if new_val > best_val
            best_deck = new_deck
            best_cargo = new_cargo
            best_val = new_val

            current_deck = new_deck
            current_cargo = new_cargo
            current_val = new_val

            score_d[d] += sig1
            score_r[r] += sig1

            accepted = true

        elseif new_val > current_val

            current_deck = new_deck
            current_cargo = new_cargo
            current_val = new_val

            score_d[d] += sig2
            score_r[r] += sig2

            accepted = true

        elseif rand() < 0.1

            current_deck = new_deck
            current_cargo = new_cargo
            current_val = new_val

            score_d[d] += sig3
            score_r[r] += sig3

            accepted = true
        end

        push!(history, best_val)

        # weight updates
        if it % segment == 0
            println("iteraion $it")
            for i in 1:nd
                if use_d[i] > 0
                    w_d[i] = (1-rho)*w_d[i] + rho*(score_d[i]/use_d[i])
                end
            end

            for i in 1:nr
                if use_r[i] > 0
                    w_r[i] = (1-rho)*w_r[i] + rho*(score_r[i]/use_r[i])
                end
            end

            score_d .= 0
            score_r .= 0
            use_d .= 0
            use_r .= 0
        end
    end
    timespent = time() -t1 
    println("ran $its iterations and $timespent seconds")

    return best_deck, history
end

function alns_hansen_fast(deck, cargo;
        destroy_ops = [destroy_neighborf, destroy_areaf, destroy_portf, destroy_randomf, destroy_shifting_costf],
        repair_ops = [repair_greedyf, repair_neighbor_randf,repair_placementf, repair_randomf],
        init = load_random,
        iterations = 10000,
        time_lim = 100000, 
        segment = 100,
        rho = 0.1)

    sig1, sig2, sig3 = 33, 9, 3
    t1 = time()
    nd = length(destroy_ops)
    nr = length(repair_ops)

    w_d = ones(nd)
    w_r = ones(nr)

    score_d = zeros(nd)
    score_r = zeros(nr)

    use_d = zeros(nd)
    use_r = zeros(nr)

    best_deck, best_cargo = init(deck, cargo)
    best_val = evaluate_sol(best_deck, best_cargo)

    current_deck = copy(best_deck)
    current_cargo = copy(best_cargo)
    current_val = best_val

    history = []
    its = 0
    for it in 1:iterations
        its = it
        timespent = time() -t1 
        if timespent > time_lim
            print("ran $it iterations and $timespent seconds")
            return best_deck, history
        end
        d = sample(1:length(destroy_ops), Weights(w_d))
        r = sample(1:length(repair_ops),  Weights(w_r))

        destroy = destroy_ops[d]
        repair = repair_ops[r]
        use_d[d] += 1
        use_r[r] += 1

        destroyed_deck, cargo2place, destroyed_cargo =
            destroy(current_deck, current_cargo)

        new_deck, new_cargo =
            repair(destroyed_deck, cargo2place, destroyed_cargo)

        new_val = evaluate_sol(new_deck, new_cargo)

        accepted = false

        if new_val > best_val
            best_deck = new_deck
            best_cargo = new_cargo
            best_val = new_val

            current_deck = new_deck
            current_cargo = new_cargo
            current_val = new_val

            score_d[d] += sig1
            score_r[r] += sig1

            accepted = true

        elseif new_val > current_val

            current_deck = new_deck
            current_cargo = new_cargo
            current_val = new_val

            score_d[d] += sig2
            score_r[r] += sig2

            accepted = true

        elseif rand() < 0.1

            current_deck = new_deck
            current_cargo = new_cargo
            current_val = new_val

            score_d[d] += sig3
            score_r[r] += sig3

            accepted = true
        end

        push!(history, best_val)

        # weight updates
        if it % segment == 0
            println("iteraion $it")
            for i in 1:nd
                if use_d[i] > 0
                    w_d[i] = (1-rho)*w_d[i] + rho*(score_d[i]/use_d[i])
                end
            end

            for i in 1:nr
                if use_r[i] > 0
                    w_r[i] = (1-rho)*w_r[i] + rho*(score_r[i]/use_r[i])
                end
            end

            score_d .= 0
            score_r .= 0
            use_d .= 0
            use_r .= 0
        end
    end
    timespent = time() -t1 
    println("ran $its iterations and $timespent seconds")

    return best_deck, history
end