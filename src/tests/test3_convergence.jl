using Statistics, Plots, Printf, Random

include(joinpath(pwd(), "src/deck_representation.jl"))
include(joinpath(pwd(), "src/cargo_generation.jl"))
include(joinpath(pwd(), "src/Heuristics/load_random.jl"))
include(joinpath(pwd(), "src/tests/run_alns.jl"))

# ── Decks ─────────────────────────────────────────────────────────────────────

deckA_struct = Deck(7, 10,
    [[1 10],[2 10],[6 10],[7 10]],
    [[3 10],[4 10],[5 10]])
deckAmat = create_deck(deckA_struct)

deckB_struct = Deck(8, 13,
    [[1,1],[2,1],[3,1],[6,1],[7,1],[8,1],
     [1,2],[2,2],[7,2],[8,2],
     [1,3],[8,3],
     [3,7],[4,7],[5,7],[6,7],
     [3,8],[4,8],[5,8],[6,8],
     [3,9],[4,9],[5,9],[6,9],
     [3,10],[4,10],[5,10],[6,10],
     [3,11],[4,11],[5,11],[6,11],
     [4,12],[5,12],
     [1,13],[8,13]],
    [[2,13],[3,13],[4,13],[5,13],[6,13],[7,13]])
deckBmat = create_deck(deckB_struct)

# ── Parameters ────────────────────────────────────────────────────────────────

const N_INSTANCES   = 1
const N_RUNS        = 20
const MAX_ITER      = 50_000
const STEP          = 500
const N_CHECKPOINTS = MAX_ITER ÷ STEP

const TIMECOST    = 500 / 60
const PCOSTSHIFT  = 250
const HANDLING    = 7
const NUM_OPS     = 1

const DECKA_LEGAL = 63
const DECKB_LEGAL = 58

scenarios = [
    (name = "DeckA – Low fill (20%)",  deck = deckAmat, n_cargo = round(Int, 0.20 * DECKA_LEGAL)),
    (name = "DeckA – High fill (90%)", deck = deckAmat, n_cargo = floor(Int, 0.90 * DECKA_LEGAL)),
    (name = "DeckB – Low fill (20%)",  deck = deckBmat, n_cargo = round(Int, 0.20 * DECKB_LEGAL)),
    (name = "DeckB – High fill (90%)", deck = deckBmat, n_cargo = floor(Int, 0.90 * DECKB_LEGAL)),
]

# ── Generate instances (fixed seed for reproducibility) ───────────────────────

Random.seed!(4242)
scenario_instances = [
    [genereate_cargo_structs(sc.n_cargo, seed = rand(1:10_000)) for _ in 1:N_INSTANCES]
    for sc in scenarios
]

# ── Shared runner (used by both smoke test and full analysis) ─────────────────

function run_convergence(scenarios, instances_per_scenario, n_runs, max_iter, step)
    n_checkpoints = max_iter ÷ step
    all_results  = []
    scenario_spi = []

    for (sc_i, sc) in enumerate(scenarios)
        println("\n=== Scenario $sc_i/$(length(scenarios)): $(sc.name)  ($(sc.n_cargo) cargo) ===")
        instances = instances_per_scenario[sc_i]
        n_inst = length(instances)
        sc_histories = []
        inst_spi = Float64[]

        for (inst_i, cargo) in enumerate(instances)
            print("  Instance $inst_i/$n_inst ... ")
            t0 = time()
            inst_histories = Vector{Float64}[]

            for _ in 1:n_runs
                d, c, h = alns_hansen_basket(sc.deck, cargo;
                    iterations    = max_iter,
                    time_lim      = 10^7,
                    timecost      = TIMECOST,
                    pcostshift    = PCOSTSHIFT,
                    handling_time = HANDLING,
                    num_operators = NUM_OPS,
                    print_status  = false)
                push!(inst_histories, [Float64(h[s * step]) for s in 1:n_checkpoints])
            end

            elapsed = time() - t0
            push!(inst_spi, elapsed / (n_runs * max_iter))
            push!(sc_histories, inst_histories)
            @printf("done (%.1f s,  %.3f ms/iter)\n", elapsed,
                    elapsed / (n_runs * max_iter) * 1000)
        end

        push!(all_results,  sc_histories)
        push!(scenario_spi, mean(inst_spi))
        @printf("  → Scenario %d avg: %.3f ms/iter\n", sc_i, mean(inst_spi) * 1000)
    end

    return all_results, scenario_spi
end

function build_plots(scenarios, all_results, scenario_spi, n_runs, max_iter, step, save_prefix)
    n_checkpoints = max_iter ÷ step
    n_instances   = length(all_results[1])
    n_total       = n_instances * n_runs
    plots_list    = Plots.Plot[]

    for (sc_i, sc) in enumerate(scenarios)
        sc_histories = all_results[sc_i]
        avg_spi = scenario_spi[sc_i]

        checkpoint_times = [(s * step * avg_spi) / 60 for s in 1:n_checkpoints]

        best_known = maximum(
            sc_histories[inst_i][r][n_checkpoints]
            for inst_i in 1:n_instances
            for r in 1:n_runs
        )

        pgbk_matrix = Matrix{Float64}(undef, n_total, n_checkpoints)
        row = 1
        for inst_i in 1:n_instances
            for r in 1:n_runs
                for s in 1:n_checkpoints
                    pgbk_matrix[row, s] =
                        (best_known - sc_histories[inst_i][r][s]) / abs(best_known) * 100
                end
                row += 1
            end
        end

        pgbk_mean = vec(mean(pgbk_matrix, dims = 1))
        pgbk_ci   = 1.96 .* vec(std(pgbk_matrix, dims = 1)) ./ sqrt(n_total)

        p = Plots.plot(
            checkpoint_times, pgbk_mean,
            ribbon    = pgbk_ci,
            fillalpha = 0.25,
            linewidth = 2,
            label     = "Mean PGBK (95% CI, $n_total runs)",
            xlabel    = "Time (minutes)",
            ylabel    = "Gap to best known (%)",
            title     = sc.name,
            dpi       = 150,
        )

        fname = "$(save_prefix)_sc$(sc_i).png"
        Plots.savefig(p, fname)
        println("  Saved: $fname")
        push!(plots_list, p)
        @printf("  Scenario %d  best_known=%.0f  final_gap=%.4f%%\n",
                sc_i, best_known, pgbk_mean[end])
    end

    fig = Plots.plot(plots_list..., layout = (2, 2), size = (1200, 800))
    combined = "$(save_prefix)_deckAB.png"
    Plots.savefig(fig, combined)
    println("  Saved: $combined")
end

# ── Smoke test ────────────────────────────────────────────────────────────────

function smoke_test()
    println("── Smoke test (1 instance, 2 runs, 1000 iterations) ──")
    ST_RUNS  = 2
    ST_ITER  = 1000
    ST_STEP  = 100

    Random.seed!(99)
    smoke_instances = [
        [genereate_cargo_structs(sc.n_cargo, seed = rand(1:10_000))]
        for sc in scenarios
    ]

    results, spi = run_convergence(scenarios, smoke_instances, ST_RUNS, ST_ITER, ST_STEP)

    for (sc_i, _) in enumerate(scenarios)
        best = maximum(
            results[sc_i][1][r][ST_ITER ÷ ST_STEP]
            for r in 1:ST_RUNS
        )
        @assert isfinite(best) "Smoke test: scenario $sc_i returned non-finite value"
    end
    println("  All assertions passed  ✓")

    build_plots(scenarios, results, spi, ST_RUNS, ST_ITER, ST_STEP, "smoke_convergence")
    println("── Smoke test passed ──\n")
end

# ── Entry point ───────────────────────────────────────────────────────────────

println("=" ^ 64)
println("  CONVERGENCE ANALYSIS  —  Deck A & B")
@printf("  Instances=%d  Runs/inst=%d  MaxIter=%d  Step=%d\n",
        N_INSTANCES, N_RUNS, MAX_ITER, STEP)
@printf("  Total runs per scenario: %d\n", N_INSTANCES * N_RUNS)
@printf("  Params: timecost=%.0f €/h  pcostshift=%d €  handling=%d min  num_ops=%d\n",
        TIMECOST * 60, PCOSTSHIFT, HANDLING, NUM_OPS)
println("=" ^ 64)

smoke_test()

# ── Run all scenarios ─────────────────────────────────────────────────────────

all_results  = []
scenario_spi = []

t_total = time()
all_results, scenario_spi = run_convergence(scenarios, scenario_instances, N_RUNS, MAX_ITER, STEP)

@printf("\nAll runs done in %.1f s\n", time() - t_total)

println("\n--- Plotting ---")
build_plots(scenarios, all_results, scenario_spi, N_RUNS, MAX_ITER, STEP, "convergence")
println("=== DONE ===")
