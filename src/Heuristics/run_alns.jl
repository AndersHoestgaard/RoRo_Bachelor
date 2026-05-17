
include(joinpath(pwd(), "src/Heuristics/alns_arrival_time.jl"))
include(joinpath(pwd(), "src/Heuristics/grasp.jl"))

include("obj_func.jl")

using StatsBase: sample, Weights
using Random


function alns_hansen_basket(deck, cargo;
        destroy_ops = [destroy_area_basket ,destroy_neighbor_basket_v2, destroy_port_basket, destroy_random_basket, destroy_shifting_cost_basket,destroy_lanes,destroy_latest],
        repair_ops = [repair_neighbor_basket_v2, repair_placement_basket, repair_random_basket,repair_in_basket, repair_out_basket],
        init = grasp,
        iterations = 200000,
        time_lim = 10000,
        segment = 100,
        eta = 0.1,
        cooling_rate = 0.9975,
        P = 0.4,
        delta = 0.2,
        sig1 = 33,
        sig2 = 9,
        sig3 = 3,
        xi = 0.1,
        stagnation_increase_after = 50,
        stagnation_restart_after = 10000,
        ret_weights = false,
        pcostshift = 250, 
        timecost = 500/60,
        handling_time = 7,
        num_operators = 1,
        print_status=false,
        early_stop_thres = false,
        grasp_its = 500)

    t1 = time()
    nd = length(destroy_ops)
    nr = length(repair_ops)

    w_d = ones(nd)
    w_r = ones(nr)
    w_r[4] = 0.1


    his_w_d = []
    his_w_r = []

    score_d = zeros(nd)
    score_r = zeros(nr)

    use_d = zeros(nd)
    use_r = zeros(nr)

    if init == grasp
        best_deck, best_cargo = init(deck, cargo;
            pcostshift = pcostshift, 
            timecost = timecost,
            handling_time = handling_time,
            num_operators = num_operators,
            max_iter=grasp_its) 
    else
        best_deck, best_cargo = init(deck, cargo)
    end


    best_val = evaluate_sol(best_deck, 
                            best_cargo,
                            pcostshift=pcostshift,
                            timecost = timecost,
                            handling_time = handling_time,
                            num_operators = num_operators,
                            )
    
    

    current_deck = deepcopy(best_deck)
    current_cargo = deepcopy(best_cargo)
    current_basket = []

    current_val = best_val

    # adaptive xi state
    xi_current = xi
    iter_since_improve = 0

    history = []
    its = 0
    it_found = 0
    t_found = 0
    target_delta = abs(best_val)* delta
    temperature = -target_delta / log(P)

    for it in 1:iterations
        
        its = it
        timespent = time() -t1
        if timespent > time_lim
            println("ran $it iterations and $timespent seconds") 
            if ret_weights
                return best_deck, history, his_w_d, his_w_r, destroy_ops, repair_ops
            elseif early_stop_thres != false
                return best_deck, best_cargo, history, t_found
            else
                return best_deck, best_cargo, history
            end
        end
        d = sample(1:length(destroy_ops), Weights(w_d))
        r = sample(1:length(repair_ops),  Weights(w_r))

        destroy = destroy_ops[d]
        repair = repair_ops[r]

        use_d[d] += 1
        use_r[r] += 1
        destroyed_deck, cargo2place, destroyed_cargo, dbasket =
            destroy(current_deck, current_cargo, current_basket, xi = xi_current)

        new_deck, new_cargo, new_basket=
            repair(destroyed_deck, cargo2place, destroyed_cargo,dbasket)

        new_val = evaluate_sol(new_deck, new_cargo,pcostshift=pcostshift,
                            timecost = timecost,
                            handling_time = handling_time,
                            num_operators = num_operators,
                            )


        accepted = false
        if new_val > best_val
            t_found = time()-t1
            it_found = its
            best_deck = deepcopy(new_deck)
            best_cargo = deepcopy(new_cargo)
            best_val = new_val


            current_deck = new_deck
            current_cargo = new_cargo
            current_val = new_val

            score_d[d] += sig1
            score_r[r] += sig1

            accepted = true

            # decrease removal size when a new best is found
            #xi_current = max(xi_min, xi_current - xi_step_down)
            iter_since_improve = 0

        elseif new_val > current_val

            current_deck = new_deck
            current_cargo = new_cargo
            current_val = new_val
            current_basket = new_basket

            score_d[d] += sig2
            score_r[r] += sig2

            accepted = true

            # slight decrease on accepted improvement
            #xi_current = max(xi_min, xi_current - xi_step_down/2)
            iter_since_improve = 0

        elseif exp((new_val-current_val)/temperature) > rand()

            current_deck = new_deck
            current_cargo = new_cargo
            current_val = new_val
            current_basket = new_basket

            score_d[d] += sig3
            score_r[r] += sig3

            accepted = true
                iter_since_improve += 1
            else
                iter_since_improve += 1
        end

        push!(history, best_val)
        temperature *= cooling_rate

        if early_stop_thres != false && (its-it_found) > early_stop_thres 
            println("ran $its iterations and $timespent seconds")
            if ret_weights
                return best_deck, history, his_w_d, his_w_r, destroy_ops, repair_ops
            end
            return best_deck, best_cargo, history, t_found
        end
        # weight updates
        if it % segment == 0
            if print_status println("iteraion $it") end
            for i in 1:nd
                if use_d[i] > 0
                    w_d[i] = (1-eta)*w_d[i] + eta*(score_d[i]/use_d[i])
                end
            end

            for i in 1:nr
                if use_r[i] > 0
                    w_r[i] = (1-eta)*w_r[i] + eta*(score_r[i]/use_r[i])
                end
            end

            if ret_weights
                push!(his_w_d, copy(w_d))
                push!(his_w_r, copy(w_r))
            end

            score_d .= 0
            score_r .= 0
            use_d .= 0
            use_r .= 0
        end

        # if stuck for a very long time, restart with a new initial solution
        if iter_since_improve >= stagnation_restart_after
            if print_status
                println("Restarting with new initial solution at iteration $it after $iter_since_improve iterations without improvement")
            end
            
            # Generate new initial solution
            if init == grasp
                current_deck, current_cargo = init(deck, cargo;
                    pcostshift = pcostshift, 
                    timecost = timecost,
                    handling_time = handling_time,
                    num_operators = num_operators,
                    max_iter=grasp_its) 
            else
                current_deck, current_cargo = init(deck, cargo)
            end
            
            current_val = evaluate_sol(current_deck, current_cargo,
                                        pcostshift=pcostshift,
                                        timecost = timecost,
                                        handling_time = handling_time,
                                        num_operators = num_operators,
                                        )
            current_basket = []
            
            # Reset iteration counter and temperature for fresh start
            iter_since_improve = 0
            target_delta = best_val * delta
            temperature = -target_delta / log(P)
            
        # if stuck for a while, increase removal fraction to diversify (disabled logic)
        elseif iter_since_improve >= stagnation_increase_after
            #xi_current = min(xi_max, xi_current + xi_step_up)
            iter_since_improve = 0
        end
    end
    timespent = time() -t1 
    println("ran $its iterations and $timespent seconds")

    if ret_weights
        return best_deck, history, his_w_d, his_w_r, destroy_ops, repair_ops
    elseif early_stop_thres != false
                return best_deck, best_cargo, history, t_found
    else
        return best_deck, best_cargo, history
    end
    
end