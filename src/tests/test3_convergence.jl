# ============================================================
# test4_convergence_scenarios.jl  –  4-scenario convergence analysis
#
# Scenarios:
#   1. DeckA  – low fill  (20% of 63 available slots =  13 cargo)
#   2. DeckA  – high fill (90% of 63 available slots =  57 cargo)
#   3. DeckC  – low fill  (20% of 305 available slots =  61 cargo)
#   4. DeckC  – high fill (90% of 305 available slots = 275 cargo)
#
# Design: 1 training instance × 20 independent runs × 20,000 iterations.
# The convergence analysis shows that ALNS converges stochastically —
# multiple runs on the same instance reveals variance across runs.
# Separate training instances (20) and test instances (5) are reserved
# for parameter tuning and sensitivity analysis respectively.
#
# Initialization: GRASP (default in alns_hansen_basket)
# Revenue: 5 discrete contract values [6000, 6750, 7500, 8250, 9000]
#
# Run from project root:
#   caffeinate -i julia src/tests/test4_convergence_scenarios.jl
#
# Expected runtime: ~50 minutes (all 4 scenarios)
# Output: convergence_4scenarios.png  +  convergence_sc1.png ... sc4.png
# ============================================================

using Statistics, Plots, Printf, Random

# --- Includes ---
include(joinpath(pwd(), "src/deck_representation.jl"))
include(joinpath(pwd(), "src/cargo_generation.jl"))
include(joinpath(pwd(), "src/tests/convergence_analysis.jl"))

# --- Build decks inline (avoids double-include of deck_representation.jl) ---

# DeckA: 7×10 = 70 total, 4 unavailable, 3 ramp → 63 cargo slots
deckA_struct = Deck(7, 10,
    [[1 10],[2 10],[6 10],[7 10]],
    [[3 10],[4 10],[5 10]])
deckAmat = create_deck(deckA_struct)

# DeckC: 12×30 = 360 total, 49 unavailable, 6 ramp → 305 cargo slots
deckC_unava = [
    [1 1],[1 2],[1 3],[2 3],[3 2],[3 1],[3 2],[2 1],[2 2],[4 1],[1 4],
    [12 1],[12 2],[12 3],[12 4],[11 1],[11 2],[11 3],[10 1],[10 2],[9 1],
    [5 13],[5 14],[6 14],[6 13],[7 14],[7 13],[8 14],[8 13],[9 14],[9 13],
    [10 14],[10 13],[11 14],[11 13],
    [1 30],[2 30],[3 30],[10 30],[11 30],[12 30],
    [1 25],[1 26],[2 25],[2 26],[11 25],[11 26],[12 25],[12 26],
]
deckC_struct = Deck(12, 30, deckC_unava,
    [[4 30],[5 30],[6 30],[7 30],[8 30],[9 30]])
deckCmat = create_deck(deckC_struct)

# --- Parameters ---
N_RUNS        = 20      # independent stochastic runs per instance
N_INSTANCES   = 1       # one fixed instance per scenario (convergence, not statistics)
MAX_ITER      = 20000   # enough iterations to reach plateau
STEP          = 500     # record best value every STEP iterations → 40 checkpoints
N_CHECKPOINTS = Int(MAX_ITER / STEP)

# --- Scenario definitions ---
DECKA_AVAIL = 63
DECKC_AVAIL = 305

scenarios = [
    (name = "DeckA – Low fill (20%)",  deck = deckAmat, n_cargo = round(Int, 0.20 * DECKA_AVAIL)),
    (name = "DeckA – High fill (90%)", deck = deckAmat, n_cargo = round(Int, 0.90 * DECKA_AVAIL)),
    (name = "DeckC – Low fill (20%)",  deck = deckCmat, n_cargo = round(Int, 0.20 * DECKC_AVAIL)),
    (name = "DeckC – High fill (90%)", deck = deckCmat, n_cargo = round(Int, 0.90 * DECKC_AVAIL)),
]

# --- Fixed seed for reproducibility ---
Random.seed!(4242)
scenario_instances = [
    [genereate_cargo_structs(sc.n_cargo, seed = rand(1:10000)) for _ in 1:N_INSTANCES]
    for sc in scenarios
]

println("=" ^ 60)
println("4-SCENARIO CONVERGENCE ANALYSIS")
println("N_RUNS=$N_RUNS  N_INSTANCES=$N_INSTANCES  MAX_ITER=$MAX_ITER  STEP=$STEP")
println("=" ^ 60)
println()

scenario_results = []    # Vector{Vector{Vector{Any}}}, one per scenario
scenario_spi     = []    # avg sec/iter per scenario

# --- Run all scenarios ---
for (sc_i, sc) in enumerate(scenarios)
    println("=== Scenario $sc_i/$(length(scenarios)): $(sc.name)  ($(sc.n_cargo) cargo) ===")
    instances = scenario_instances[sc_i]
    all_results = Vector{Vector{Vector{Any}}}()
    inst_spi = Float64[]

    for (inst_i, cargo) in enumerate(instances)
        print("  Instance $inst_i/$N_INSTANCES ... ")
        t0 = time()
        ob_vals = convergence_analysis(sc.deck, cargo;
                                       runs_per_it    = N_RUNS,
                                       max_iterations = MAX_ITER,
                                       stepsize       = STEP)
        elapsed = time() - t0
        spi = elapsed / (N_RUNS * MAX_ITER)
        push!(inst_spi, spi)
        push!(all_results, ob_vals)
        @printf("done (%.1f s total, %.3f ms/iter)\n", elapsed, spi * 1000)
    end

    push!(scenario_results, all_results)
    push!(scenario_spi, mean(inst_spi))
    @printf("  → Scenario avg: %.3f ms/iter\n\n", mean(inst_spi) * 1000)
end

# --- PGBK computation and plotting ---
n_total    = N_INSTANCES * N_RUNS
plots_list = []

for (sc_i, sc) in enumerate(scenarios)
    all_results = scenario_results[sc_i]
    avg_spi     = scenario_spi[sc_i]

    # Time axis: checkpoint s = s*STEP iterations into a single run
    CHECKPOINT_TIMES = [(s * STEP * avg_spi) / 60 for s in 1:N_CHECKPOINTS]

    best_known = maximum(
        Float64(ob_vals[N_CHECKPOINTS][r])
        for ob_vals in all_results
        for r in 1:N_RUNS
    )

    pgbk_matrix = let
        mat = Matrix{Float64}(undef, n_total, N_CHECKPOINTS)
        row = 1
        for ob_vals in all_results
            for r in 1:N_RUNS
                for s in 1:N_CHECKPOINTS
                    mat[row, s] = (best_known - Float64(ob_vals[s][r])) / abs(best_known) * 100
                end
                row += 1
            end
        end
        mat
    end

    pgbk_mean = vec(mean(pgbk_matrix, dims=1))
    pgbk_ci   = 1.96 .* vec(std(pgbk_matrix, dims=1)) ./ sqrt(n_total)

    p = Plots.plot(
        CHECKPOINT_TIMES, pgbk_mean,
        ribbon    = pgbk_ci,
        fillalpha = 0.25,
        linewidth = 2,
        label     = "Mean PGBK (95% CI, $N_RUNS runs)",
        xlabel    = "Time (minutes)",
        ylabel    = "Gap to best known (%)",
        title     = sc.name,
        dpi       = 150,
    )

    fname = "convergence_sc$(sc_i).png"
    Plots.savefig(p, fname)
    println("Saved: $fname")

    push!(plots_list, p)
    @printf("Scenario %d  best_known=%.0f  final_gap=%.2f%%\n",
            sc_i, best_known, pgbk_mean[end])
end

println()
fig = Plots.plot(plots_list..., layout = (2, 2), size = (1200, 800))
Plots.savefig(fig, "convergence_4scenarios.png")
println("Saved: convergence_4scenarios.png")
println("=== DONE ===")
