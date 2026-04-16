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
        max_iter = 50)  

    m, n = size(deck)

    best_deck = nothing
    best_cargo_on = nothing
    best_val = -Inf


    wD = ones(7)
    wL = ones(5)
    wI = ones(3)


    score_D = zeros(7)
    score_L = zeros(5)
    score_I = zeros(3)


    count_D = zeros(7)
    count_L = zeros(5)   
    count_I = zeros(3)   


    for it in 1:max_iter

        # --- copy inputs ---
        deck_sol = copy(deck)
        cargo_pool = copy(cargo)

        cargo_on = Array{Union{Nothing, eltype(cargo)}, 2}(nothing, m, n)

        # --- select strategies ---
        d = sample(1:7, Weights(wD))
        ins = sample(1:3, Weights(wI))
        l_index = sample(1:5, Weights(wL))
        

        # --- S: available slots ---
        S = [(i,j) for i in 1:m, j in 1:n if deck_sol[i,j] == 1]
        S = get_traversal_order(S, d, m, n)
        

        # --- main construction ---
        while !isempty(S) && !isempty(cargo_pool)

            (i,j) = popfirst!(S)

            # --- build candidate list ---
            candidates = cargo_pool

            if isempty(candidates)
                break
            end

            l = [max(1, 0.0*length(cargo_pool)),
                    max(1, 0.2*length(cargo_pool)),
                    max(1, 0.4*length(cargo_pool)),
                    max(1, 0.6*length(cargo_pool)),
                    max(1, 0.8*length(cargo_pool))][l_index]

            if ins == 1
                # prefer early departure
                RCL = sort(by = x-> x.port, candidates)[1:Int(round(l))]
            elseif ins == 2
                RCL =sort(by = x-> x.arr, candidates)[1:Int(round(l))]
            else
                RCL = shuffle(candidates)
            end


            # --- pick randomly from RCL ---
            c_sel = rand(RCL)

            # --- assign cargo ---
            cargo_on[i,j] = c_sel
            deck_sol[i,j] = c_sel.port   

            # --- remove from pool ---
            deleteat!(cargo_pool, findfirst(==(c_sel), cargo_pool))
        end

        # --- check feasibility ---
        if isempty(cargo_pool)
            val = evaluate_sol(deck_sol, cargo_on)

            if val > best_val
                best_val = val
                best_deck = deck_sol
                best_cargo_on = cargo_on
            end
        end

        count_D[d] += 1
        count_L[l_index] += 1
        count_I[ins] += 1

        score_D[d] += val
        score_L[l_index] += val
        score_I[ins] += val


        wD = score_D ./ max.(count_D, 1)
        wL = score_L ./ max.(count_L, 1)
        wI = score_I ./ max.(count_I, 1)


    end

    if best_cargo_on === nothing
        best_deck, best_cargo_on = load_random(deck, cargo)
        best_val = evaluate_sol(best_deck, best_cargo_on)
    end

    return best_deck, best_cargo_on
end