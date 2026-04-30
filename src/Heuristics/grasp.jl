using StatsBase

function get_traversal_order(S, d, m, n)

    if d == 1
        # Row-wise (top-left → bottom-right)
        sort!(S, by = x -> (x[1], x[2]))

    elseif d == 2
        # Row-wise reverse
        sort!(S, by = x -> (-x[1], -x[2]))

    elseif d == 3
        # Column-wise (left → right)
        sort!(S, by = x -> (x[2], x[1]))

    elseif d == 4
        # Column-wise reverse
        sort!(S, by = x -> (-x[2], -x[1]))

    elseif d == 5
        # Snake row-wise
        sort!(S, by = x -> (x[1], (-1)^x[1] * x[2]))

    elseif d == 6
        # Snake column-wise
        sort!(S, by = x -> (x[2], (-1)^x[2] * x[1]))


    elseif d == 7
        # Center-out (good packing structure)
        center_i, center_j = div(m,2), div(n,2)
        sort!(S, by = x -> abs(x[1]-center_i) + abs(x[2]-center_j))
    end

    return S
end

function grasp(deck, cargo;
        max_iter = 2000,
        max_time = 180,
        pcostshift = 250, 
        timecost = 500/60,
        handling_time = 7,
        num_operators = 1)  

    t1=time()
        m, n = size(deck)

    best_deck     = nothing
    best_cargo_on = nothing
    best_val      = -Inf

    # --- Search Guiding Parameters (SGPs) ---
    # D: 2 traversal orders (ramp-first, row-wise)
    # I: 3 insertion orders  (early port, short arrival, random)
    # L: 5 RCL sizes         (1, 20%, 40%, 60%, 80% of remaining cargo)


    wD = ones(7)
    wL = ones(5)
    wI = ones(2)


    score_D = zeros(7)
    score_L = zeros(5)
    score_I = zeros(2)


    count_D = zeros(7)
    count_L = zeros(5)   
    count_I = zeros(12)   


    for it in 1:max_iter
        if time()-t1 > max_time
            return best_deck, best_cargo_on 
        end
        deck_sol   = copy(deck)
        cargo_pool = copy(cargo)
        cargo_on   = Array{Union{Nothing, eltype(cargo)}, 2}(nothing, m, n)

        d = sample(1:7, Weights(wD))
        ins = sample(1:2, Weights(wI))
        l_index = sample(1:5, Weights(wL))
        

        # --- S: available slots, sorted by traversal order d ---
        S = [(i,j) for i in 1:m, j in 1:n if deck_sol[i,j] == 1]

        # remove slots that are followed by a non-slot (e.g., ramp/0) to avoid invalid placements
        S = [s for s in S if !(s[2] < n && deck_sol[s[1], s[2]+1] == 0)]
        S = get_traversal_order(S, d, m, n)

        # --- main construction loop ---
        while !isempty(S) && !isempty(cargo_pool)

            candidates =  cargo_pool
            (i,j) = popfirst!(S)

            if isempty(candidates)
                break
            end

            # RCL size choices as fractions of current candidate pool
            l_fracs = [0.0, 0.2, 0.4, 0.6, 0.8]
            l_raw = l_fracs[l_index] * length(candidates)
            k = max(1, min(length(candidates), Int(round(l_raw))))
            
            
            if ins == 1
                RCL = sort(vec(candidates), by = x-> x.port)[1:k]
            elseif ins == 2
                RCL = sort(vec(candidates), by = x-> x.arr)[1:k]
            elseif ins == 3
                RCL = sort(vec(candidates), by = x-> x.port, rev=true)[1:k]
            elseif ins == 4
                RCL = sort(vec(candidates), by = x-> x.arr, rev=true)[1:k]
            end

            # --- pick randomly from RCL ---
            c_sel = rand(RCL)

            # --- assign cargo ---
            cargo_on[i,j] = c_sel
            deck_sol[i,j] = c_sel.port   

            # --- remove from pool ---
            deleteat!(cargo_pool, findfirst(==(c_sel), cargo_pool))
        end

        # --- evaluate; update scores if all cargo placed ---
        if isempty(cargo_pool)
            val = evaluate_sol(deck_sol, 
                            cargo_on,
                            pcostshift=pcostshift,
                            timecost = timecost,
                            handling_time = handling_time,
                            num_operators = num_operators,
                            )

            if val > best_val
                best_val      = val
                best_deck     = deck_sol
                best_cargo_on = cargo_on

            elseif !isfinite(val)
                wD .= 1
                wL .= 1
                wI .= 1
            else
                count_D[d] += 1
                count_L[l_index] += 1
                count_I[ins] += 1

                score_D[d] += val
                score_L[l_index] += val
                score_I[ins] += val

                wD .= 1#score_D ./ max.(count_D, 1)
                wL .= 1#score_L ./ max.(count_L, 1)
                wI .= 1#score_I ./ max.(count_I, 1)
            end

        end
    end

    # --- fallback if no feasible solution found ---
    if best_cargo_on === nothing
        best_deck, best_cargo_on = load_random(deck, cargo)
    end

    return best_deck, best_cargo_on
end
