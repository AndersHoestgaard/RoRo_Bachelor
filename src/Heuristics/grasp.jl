using StatsBase

function grasp(deck, cargo;
        max_iter = 50,
        α = 0.3)   # controls greediness (0 = greedy, 1 = random)

    m, n = size(deck)

    best_deck = nothing
    best_cargo_on = nothing
    best_val = -Inf


    wD = ones(2)   # position ordering strategies
    wL = ones(2)   # cargo selection strategies

    for it in 1:max_iter

        # --- copy inputs ---
        deck_sol = copy(deck)
        cargo_pool = copy(cargo)

        cargo_on = Array{Union{Nothing, eltype(cargo)}, 2}(nothing, m, n)

        # --- select strategies ---
        d = sample(1:2, Weights(wD))   # ordering
        l = sample(1:2, Weights(wL))   # selection

        # --- S: available slots ---
        S = [(i,j) for i in 1:m, j in 1:n if deck_sol[i,j] == 1]

        # --- sort positions ---
        if d == 1
            # ramp-first (right side first)
            sort!(S, by = x -> -x[2])
        else
            # row-wise
            sort!(S, by = x -> (x[1], x[2]))
        end

        # --- main construction ---
        while !isempty(S) && !isempty(cargo_pool)

            (i,j) = popfirst!(S)

            # --- build candidate list ---
            candidates = cargo_pool

            if isempty(candidates)
                break
            end

            # --- score candidates ---
            scores = Float64[]

            for c in candidates
                if l == 1
                    # prefer early departure
                    push!(scores, -c.port)
                else
                    # random / neutral
                    push!(scores, rand())
                end
            end

            # --- build RCL ---
            max_s = maximum(scores)
            min_s = minimum(scores)

            threshold = max_s - α*(max_s - min_s)

            RCL = [candidates[k] for k in eachindex(candidates) if scores[k] >= threshold]

            # --- pick randomly from RCL ---
            c_sel = rand(RCL)

            # --- assign cargo ---
            cargo_on[i,j] = c_sel
            deck_sol[i,j] = c_sel.port   # match your encoding

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
    end

    return best_deck, best_cargo_on
end