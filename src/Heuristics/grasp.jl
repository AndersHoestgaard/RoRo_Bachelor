using StatsBase

function grasp(deck, cargo;
        max_iter = 50)

    m, n = size(deck)

    best_deck     = nothing
    best_cargo_on = nothing
    best_val      = -Inf

    # --- Search Guiding Parameters (SGPs) ---
    # D: 2 traversal orders (ramp-first, row-wise)
    # I: 3 insertion orders  (early port, short arrival, random)
    # L: 5 RCL sizes         (1, 20%, 40%, 60%, 80% of remaining cargo)
    nD, nI, nL = 2, 3, 5

    wD = ones(nD)
    wI = ones(nI)
    wL = ones(nL)

    sD = zeros(nD)
    sI = zeros(nI)
    sL = zeros(nL)

    uD = zeros(Int, nD)
    uI = zeros(Int, nI)
    uL = zeros(Int, nL)

    for it in 1:max_iter

        # --- copy inputs ---
        deck_sol   = copy(deck)
        cargo_pool = copy(cargo)
        cargo_on   = Array{Union{Nothing, eltype(cargo)}, 2}(nothing, m, n)

        # --- select strategies ---
        d    = sample(1:nD, Weights(wD))
        i_st = sample(1:nI, Weights(wI))
        l_ix = sample(1:nL, Weights(wL))

        uD[d]    += 1
        uI[i_st] += 1
        uL[l_ix] += 1

        # --- S: available slots, sorted by traversal order d ---
        S = [(i,j) for i in 1:m, j in 1:n if deck_sol[i,j] == 1]
        if d == 1
            sort!(S, by = x -> -x[2])   # ramp-first (right columns first)
        else
            sort!(S, by = x -> (x[1], x[2]))  # row-wise (left-to-right)
        end

        # --- main construction loop ---
        while !isempty(S) && !isempty(cargo_pool)

            (ci, cj) = popfirst!(S)
            n_remaining = length(cargo_pool)

            # --- RCL size (adaptive to how much cargo is left) ---
            rcl_sizes = [1,
                         max(1, round(Int, 0.20 * n_remaining)),
                         max(1, round(Int, 0.40 * n_remaining)),
                         max(1, round(Int, 0.60 * n_remaining)),
                         max(1, round(Int, 0.80 * n_remaining))]
            l_size = rcl_sizes[l_ix]

            # --- score candidates by insertion strategy i_st ---
            scores = map(cargo_pool) do c
                if i_st == 1
                    Float64(-c.port)        # greedy: earlier port first
                elseif i_st == 2
                    Float64(-c.arr)         # greedy: shorter arrival time first
                else
                    rand()                  # random
                end
            end

            # --- build RCL: top-l_size elements by score ---
            order = sortperm(scores, rev = true)
            l_actual = min(l_size, length(order))
            RCL = cargo_pool[order[1:l_actual]]

            # --- pick randomly from RCL ---
            c_sel = rand(RCL)

            # --- assign cargo ---
            cargo_on[ci, cj]  = c_sel
            deck_sol[ci, cj]  = c_sel.port

            # --- remove from pool ---
            deleteat!(cargo_pool, findfirst(==(c_sel), cargo_pool))
        end

        # --- evaluate; update scores if all cargo placed ---
        if isempty(cargo_pool)
            val = evaluate_sol(deck_sol, cargo_on)

            if val > best_val
                best_val      = val
                best_deck     = deck_sol
                best_cargo_on = cargo_on
            end

            # --- update SGP scores (reward proportional to objective) ---
            sD[d]    += val
            sI[i_st] += val
            sL[l_ix] += val
        end

        # --- update weights after each iteration ---
        for k in 1:nD
            wD[k] = sD[k] / max(1, uD[k])
        end
        for k in 1:nI
            wI[k] = sI[k] / max(1, uI[k])
        end
        for k in 1:nL
            wL[k] = sL[k] / max(1, uL[k])
        end
    end

    # --- fallback if no feasible solution found ---
    if best_cargo_on === nothing
        best_deck, best_cargo_on = load_random(deck, cargo)
    end

    return best_deck, best_cargo_on
end
