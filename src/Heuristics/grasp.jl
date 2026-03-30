# - Paper ranks RCL candidates by vehicle *area* (largest first, for packing efficiency).
#   We have no area per slot (all slots equal size), so we rank by cargo priority score
#   (1/port + arr), matching our existing pri_rules logic.

# ── Square sequences ──────────────────────────────────────────────────────────
# 8 orderings of usable slots, defined by starting corner and primary direction.
# Primary direction = which axis is the outer loop.
#
#   seq  corner        outer loop   inner loop
#    1   top-left      cols →       rows ↓
#    2   top-left      rows ↓       cols →
#    3   top-right     cols ←       rows ↓
#    4   top-right     rows ↓       cols ←
#    5   bottom-left   cols →       rows ↑
#    6   bottom-left   rows ↑       cols →
#    7   bottom-right  cols ←       rows ↑
#    8   bottom-right  rows ↑       cols ←

function make_square_sequence(deck_matrix::Matrix, seq_id::Int)
    h, w = size(deck_matrix)

    row_dir = seq_id in [1,2,3,4] ? (1:h) : (h:-1:1)
    col_dir = seq_id in [1,2,5,6] ? (1:w) : (w:-1:1)
    col_outer = seq_id in [1,3,5,7]   # true = cols are outer loop

    ordered = Tuple{Int,Int}[]
    if col_outer
        for j in col_dir
            for i in row_dir
                if deck_matrix[i,j] != 0   # skip unavailable slots
                    push!(ordered, (i,j))
                end
            end
        end
    else
        for i in row_dir
            for j in col_dir
                if deck_matrix[i,j] != 0
                    push!(ordered, (i,j))
                end
            end
        end
    end
    return ordered
end

# ── Roulette wheel selection ──────────────────────────────────────────────────
function roulette_wheel_select(weights::Vector{Float64})::Int
    total = sum(weights)
    r = rand() * total
    cumul = 0.0
    for (i, w) in enumerate(weights)
        cumul += w
        if cumul >= r
            return i
        end
    end
    return length(weights)
end

# ── Cargo scoring for RCL ─────────────────────────────────────────────────────
# Lower score = higher priority (same logic as pri_rules1/2).
# Replaces the paper's area-based ranking since all slots are equal size.
cargo_priority(c) = 1.0 / c.port + c.arr

# ── Build RCL ─────────────────────────────────────────────────────────────────
function make_rcl(remaining::Vector, l::Int)
    sorted = sort(remaining, by=cargo_priority)
    return sorted[1:min(l, length(sorted))]
end

# ── Single construction pass ──────────────────────────────────────────────────
# Returns (filled_deck, cargo_on_matrix, n_unplaced)
function grasp_construct(base_deck::Matrix, cargo_list::Vector;
                         rcl_length::Int=3, seq_id::Int=1)
    deck     = copy(base_deck)
    h, w     = size(deck)
    cargo_on = Matrix{Any}(nothing, h, w)
    remaining = copy(cargo_list)

    squares = make_square_sequence(deck, seq_id)

    for (i, j) in squares
        isempty(remaining) && break
        deck[i,j] == 1    || continue   # only free slots

        rcl = make_rcl(remaining, rcl_length)
        isempty(rcl) && continue

        chosen   = rand(rcl)
        deck[i,j]     = chosen.port + 2   # matches existing encoding
        cargo_on[i,j] = chosen
        filter!(c -> c !== chosen, remaining)
    end

    return deck, cargo_on, length(remaining)
end

# ── Full GRASP ────────────────────────────────────────────────────────────────
# Returns (best_deck, best_cargo_on)
function grasp(base_deck::Matrix, cargo_list::Vector;
               max_iter::Int    = 200,
               rcl_lengths      = [1, 2, 3, 4, 5],
               delta::Float64   = 0.1,
               time_limit::Float64 = 30.0)

    n_seq = 8
    n_rcl = length(rcl_lengths)

    # Initialise uniform weights (paper: wD and wL)
    w_seq = ones(Float64, n_seq)
    w_rcl = ones(Float64, n_rcl)

    best_deck     = nothing
    best_cargo_on = nothing
    best_unplaced = length(cargo_list) + 1

    prev_unplaced = length(cargo_list)
    t_start = time()

    for iter in 1:max_iter
        time() - t_start > time_limit && break

        # --- First 8 iterations: greedy pass with each sequence once (paper §3.2) ---
        if iter <= n_seq
            seq_id = iter
            l      = 1
            rcl_idx = 1
        else
            seq_id  = roulette_wheel_select(w_seq)
            rcl_idx = roulette_wheel_select(w_rcl)
            l       = rcl_lengths[rcl_idx]
        end

        deck, cargo_on, unplaced = grasp_construct(base_deck, cargo_list;
                                                    rcl_length=l, seq_id=seq_id)

        # Keep best solution (paper: "if new best, keep and do not terminate early")
        if unplaced < best_unplaced
            best_unplaced = unplaced
            best_deck     = deepcopy(deck)
            best_cargo_on = deepcopy(cargo_on)
        end

        best_unplaced == 0 && break   # perfect solution found

        # --- Weight update (paper §3.2, eq. after Alg. 2 line 18) ---
        # Reward if fewer unplaced than previous iteration, penalise otherwise.
        if iter > n_seq
            improvement = prev_unplaced - unplaced
            sign = improvement > 0 ? +1.0 : -1.0
            w_seq[seq_id]  = max(0.01, w_seq[seq_id]  + sign * delta)
            w_rcl[rcl_idx] = max(0.01, w_rcl[rcl_idx] + sign * delta)
        end

        prev_unplaced = unplaced
    end

    if best_unplaced > 0
        @warn "GRASP: $best_unplaced cargo(es) could not be placed."
    end

    return best_deck, best_cargo_on
end