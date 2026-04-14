# ============================================================
# test3_convergence.jl  –  Convergence analysis for DeckC
#
# Run from project root:
#   julia src/tests/test3_convergence.jl
# or in REPL (with pwd() set to project root):
#   include("src/tests/test3_convergence.jl")
#
# Depends on:
#   src/Decks/DeckC.jl
#   src/Cargo_instances/train_and_test_for_deckC.jl
#   src/tests/convergence_analysis.jl   (which includes run_alns.jl + obj_func.jl)
#
# Supervisor requirements:
#   - Time (minutes) on x-axis
#   - PGBK (%) on y-axis
#   - 20 independent runs per instance
#   - 95% confidence interval
#   - alns_hansen_basket (handles dynamic arrival times)
# ============================================================

using Statistics, Plots, Printf

include(joinpath(pwd(), "src/Decks/DeckC.jl"))
include(joinpath(pwd(), "src/Cargo_instances/train_and_test_for_deckC.jl"))
include(joinpath(pwd(), "src/tests/convergence_analysis.jl"))

# ── Parameters ────────────────────────────────────────────────
# Adjust these to trade off quality vs. runtime:
#   N_INSTANCES × N_RUNS × MAX_ITER × ~100ms/iter ≈ total seconds
#   5 × 20 × 300 × 0.1s ≈ 600 s  (~10 min)
N_RUNS        = 20     # independent runs per instance (supervisor requirement)
N_INSTANCES   = 5      # number of training instances to use
MAX_ITER      = 300    # ALNS iterations per run
STEP          = 15     # checkpoint every STEP iterations  (→ 20 checkpoints)
N_CHECKPOINTS = Int(MAX_ITER / STEP)

deck = deckCmat

@assert @isdefined(train_instances) "train_and_test_for_deckC.jl must define train_instances"
@assert @isdefined(test_instances)  "train_and_test_for_deckC.jl must define test_instances"

instances = train_instances[1:min(N_INSTANCES, length(train_instances))]
println("Using $N_INSTANCES / $(length(train_instances)) training instances")
println("N_RUNS=$N_RUNS | MAX_ITER=$MAX_ITER | STEP=$STEP | checkpoints=$N_CHECKPOINTS")


# ══════════════════════════════════════════════════════════════
#  MAIN EXPERIMENT
#  all_results[i] = ob_vals_collection returned by convergence_analysis
#                   ob_vals_collection[s][r] = best obj at checkpoint s, run r
# ══════════════════════════════════════════════════════════════
println("\n=== Convergence analysis: DeckC  ($N_INSTANCES instances × $N_RUNS runs) ===\n")

all_results    = Vector{Vector{Vector{Any}}}()
inst_sec_per_iter = Float64[]   # measured seconds/iteration per instance

for (inst_i, cargo) in enumerate(instances)
    println("Instance $inst_i / $N_INSTANCES  ($(length(cargo)) cargo units)...")
    t0 = time()
    ob_vals = convergence_analysis(deck, cargo;
                                   runs_per_it    = N_RUNS,
                                   max_iterations = MAX_ITER,
                                   stepsize       = STEP)
    elapsed = time() - t0
    spi = elapsed / (N_RUNS * MAX_ITER)   # seconds per iteration (averaged over all runs)
    push!(inst_sec_per_iter, spi)
    push!(all_results, ob_vals)
    @printf("  ✓ instance %d done  (%.1f s total, %.2f ms/iter)\n",
            inst_i, elapsed, spi * 1000)
end

println("\nAll runs completed.")

# Average seconds-per-iteration across all instances → shared time axis
avg_spi = mean(inst_sec_per_iter)
CHECKPOINT_TIMES = [(s * STEP * avg_spi) / 60 for s in 1:N_CHECKPOINTS]  # minutes

@printf("Average iteration speed: %.2f ms/iter\n", avg_spi * 1000)
@printf("Time axis range: 0 – %.3f min\n", CHECKPOINT_TIMES[end])


# ══════════════════════════════════════════════════════════════
#  COMPUTE PGBK  (Percentage Gap to Best Known)
#
#  best_known = best objective value found across ALL runs/instances
#  PGBK(t) = (best_known − val(t)) / |best_known| × 100
#    PGBK = 0 % → algorithm has reached the best known
#    Curve falls toward 0 as algorithm converges
# ══════════════════════════════════════════════════════════════
best_known = maximum(
    Float64(ob_vals[N_CHECKPOINTS][r])
    for ob_vals in all_results
    for r in 1:N_RUNS
)
println("Best known solution: $(round(best_known, digits=2))")

# Build PGBK matrix: rows = all runs, cols = checkpoints
n_total = N_INSTANCES * N_RUNS
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
pgbk_std  = vec(std(pgbk_matrix,  dims=1))
pgbk_ci   = 1.96 .* pgbk_std ./ sqrt(n_total)


# ══════════════════════════════════════════════════════════════
#  FIGURE 1 – Convergence curve (all instances combined)
#  Red mean curve + blue 95% CI band
# ══════════════════════════════════════════════════════════════
p1 = Plots.plot(
    CHECKPOINT_TIMES, pgbk_mean,
    ribbon        = pgbk_ci,
    fillalpha     = 0.25,
    color         = :red,
    fillcolor     = :blue,
    linewidth     = 2,
    label         = "Mean PGBK  ($N_INSTANCES instances × $N_RUNS runs)",
    xlabel        = "Time (minutes)",
    ylabel        = "Gap to best known solution (%)",
    title         = "ALNS Convergence (Mean + 95% CI) – DeckC",
    legend        = :topright,
    ylims         = (0, max(pgbk_mean[1] * 1.2, 1.0)),
    guidefontsize = 11,
    titlefontsize = 12,
    dpi           = 150,
)
Plots.hline!(p1, [0.0], linestyle=:dash, color=:black,
             linewidth=1, label="Best known (gap = 0%)")
Plots.savefig(p1, "convergence_deckC.png")
println("Convergence figure saved: convergence_deckC.png")


# ══════════════════════════════════════════════════════════════
#  FIGURE 2 – Per-instance curves + overall mean
# ══════════════════════════════════════════════════════════════
inst_colors = [:cornflowerblue, :mediumseagreen, :goldenrod,
               :mediumpurple,   :salmon]

p2 = Plots.plot(
    xlabel = "Time (minutes)",
    ylabel = "Gap to best known solution (%)",
    title  = "ALNS Convergence – DeckC per instance",
    legend = :topright, dpi = 150,
)

for (inst_i, ob_vals) in enumerate(all_results)
    inst_pgbk = Matrix{Float64}(undef, N_RUNS, N_CHECKPOINTS)
    for r in 1:N_RUNS, s in 1:N_CHECKPOINTS
        inst_pgbk[r, s] = (best_known - Float64(ob_vals[s][r])) / abs(best_known) * 100
    end
    inst_mean = vec(mean(inst_pgbk, dims=1))
    Plots.plot!(p2, CHECKPOINT_TIMES, inst_mean,
                color     = inst_colors[mod1(inst_i, length(inst_colors))],
                alpha     = 0.7,
                linewidth = 1.5,
                label     = "Instance $inst_i")
end

Plots.plot!(p2, CHECKPOINT_TIMES, pgbk_mean,
            color = :red, linewidth = 2.5, label = "Overall mean",
            linestyle = :solid)
Plots.hline!(p2, [0.0], linestyle=:dash, color=:black,
             linewidth=1, label=false)
Plots.savefig(p2, "convergence_deckC_per_instance.png")
println("Per-instance figure saved: convergence_deckC_per_instance.png")


# ══════════════════════════════════════════════════════════════
#  CONVERGENCE TABLE  (for report)
# ══════════════════════════════════════════════════════════════
println("\n=== Convergence table (selected time points) ===")
println("Time (min) | PGBK mean (%) | 95% CI (±%)")
println("-" ^ 42)
idx_show = round.(Int, range(1, N_CHECKPOINTS, length=10))
for i in idx_show
    @printf("  %5.3f   |   %7.4f     |  %7.4f\n",
            CHECKPOINT_TIMES[i], pgbk_mean[i], pgbk_ci[i])
end

println("\n=== PGBK decrease per time interval ===")
step_show = max(1, N_CHECKPOINTS ÷ 6)
for i in (step_show+1):step_show:N_CHECKPOINTS
    Δ = pgbk_mean[i-step_show] - pgbk_mean[i]
    @printf("  %.3f → %.3f min :  PGBK decreased %.4f percentage points\n",
            CHECKPOINT_TIMES[i-step_show], CHECKPOINT_TIMES[i], Δ)
end

println("\n=== FINISHED ===")
