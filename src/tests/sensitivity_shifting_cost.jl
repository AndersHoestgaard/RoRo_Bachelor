# sensitivity_shifting_cost.jl — run from repo root:
#   julia --project src/tests/sensitivity_shifting_cost.jl
#
# Sensitivity analysis on pcostshift (€/shift) only.
# All other parameters held at baseline.

t_load = time()
println("Loading dependencies...")

include(joinpath(pwd(), "src/Heuristics/load_random.jl"))
include(joinpath(pwd(), "src/tests/run_alns.jl"))

include(joinpath(pwd(), "src/Decks/DeckA.jl"))
include(joinpath(pwd(), "src/Cargo_instances/train_and_test_for_deckA.jl"))

using Statistics: mean, std
using Printf
using Plots

println("Loaded in $(round(time()-t_load, digits=2)) s\n")

# ── Parameters ────────────────────────────────────────────────────────────────
const SC_TIMECOST    = 500 / 60
const SC_HANDLING    = 7
const SC_NUM_OPS     = 1
const SC_PATIENCE    = 10000

const SHIFT_COSTS    = [50, 100, 150, 250, 500, 750, 1000]   # €/shift

test_set(arr) = arr[end-test_size+1:end]
ci95(x) = length(x) > 1 ? 1.96 * std(x) / sqrt(length(x)) : 0.0

# ── Runner ────────────────────────────────────────────────────────────────────
function run_shift_instances(deck, instances, pcostshift; patience = SC_PATIENCE)
    obj_vals = Float64[]
    n_cargo  = Int[]
    n_shifts = Float64[]

    for cargo in instances
        d, c, _, _ = alns_hansen_basket(deck, cargo;
            timecost         = SC_TIMECOST,
            pcostshift       = pcostshift,
            handling_time    = SC_HANDLING,
            num_operators    = SC_NUM_OPS,
            early_stop_thres = patience,
            print_status     = false)

        push!(obj_vals, evaluate_sol(d, c;
            timecost      = SC_TIMECOST,
            pcostshift    = pcostshift,
            handling_time = SC_HANDLING,
            num_operators = SC_NUM_OPS))
        push!(n_cargo,  count(!isnothing, c))
        push!(n_shifts, min_shift_all_cargo_work(d))
    end

    return obj_vals, n_cargo, n_shifts
end

# ── Smoke test ────────────────────────────────────────────────────────────────
function smoke_test_shift()
    println("── Smoke test (1 instance, patience=50) ──")
    inst = [cargo_a_90_6[end]]

    objs, cargos, shifts = run_shift_instances(deckAmat, inst, 250; patience = 50)
    @assert isfinite(objs[1]) "Baseline not finite: $(objs[1])"
    @printf("  pcostshift=250:   obj = %.0f €, cargo = %.0f, shifts = %.2f  ✓\n",
            objs[1], cargos[1], shifts[1])

    objs_h, _, _ = run_shift_instances(deckAmat, inst, 1000; patience = 50)
    @assert isfinite(objs_h[1]) "pcostshift=1000 not finite"
    println("  pcostshift=1000  ✓")

    objs_l, _, _ = run_shift_instances(deckAmat, inst, 50; patience = 50)
    @assert isfinite(objs_l[1]) "pcostshift=50 not finite"
    println("  pcostshift=50    ✓")
    println("── Smoke test passed ──\n")
end

# ── Run ───────────────────────────────────────────────────────────────────────
smoke_test_shift()

t_start = time()
test_A   = test_set(cargo_a_90_6)
baseline = 250   # matches BASE_PCOSTSHIFT in sensitivity_analysis.jl

println("═"^68)
println("  Shifting Cost Sensitivity — Deck A   ($(length(test_A)) test instances)")
println("  Baseline pcostshift = $baseline €/shift")
println("  Other params: timecost=$(round(SC_TIMECOST*60;digits=0)) €/h, " *
        "handling=$(SC_HANDLING) min, num_operators=$(SC_NUM_OPS)")
println("  ALNS patience=$(SC_PATIENCE), init=load_random")
println("═"^68)

base_objs, base_cargos, base_shifts_v = run_shift_instances(deckAmat, test_A, baseline)
base_obj    = mean(base_objs)
base_cargo  = mean(base_cargos)
base_shifts = mean(base_shifts_v)
@printf("\n  Baseline (pcostshift=%d €):  obj = %.0f € (±%.0f)   cargo = %.2f   shifts = %.2f\n\n",
        baseline, base_obj, ci95(base_objs), base_cargo, base_shifts)

mean_objs    = Float64[]
mean_cargos  = Float64[]
mean_shifts  = Float64[]
Δobj_means   = Float64[]
Δobj_cis     = Float64[]
Δshift_means = Float64[]
Δshift_cis   = Float64[]

for pc in SHIFT_COSTS
    print("  pcostshift = $pc €/shift ...")
    objs, cargos, shifts = run_shift_instances(deckAmat, test_A, pc)
    Δobj_i   = 100 .* (objs   .- base_obj)   ./ abs(base_obj)
    Δshift_i = 100 .* (shifts .- base_shifts) ./ max(base_shifts, 1.0)
    push!(mean_objs,    mean(objs))
    push!(mean_cargos,  mean(cargos))
    push!(mean_shifts,  mean(shifts))
    push!(Δobj_means,   mean(Δobj_i))
    push!(Δobj_cis,     ci95(Δobj_i))
    push!(Δshift_means, mean(Δshift_i))
    push!(Δshift_cis,   ci95(Δshift_i))
    @printf(" done  (Δobj %+.1f%%, mean shifts = %.2f)\n", mean(Δobj_i), mean(shifts))
end

# ── Table ─────────────────────────────────────────────────────────────────────
println()
println("  " * "─"^72)
@printf("  %-12s │ %11s │ %14s │ %10s │ %14s\n",
        "pcostshift", "Mean Obj (€)", "Δ Obj (%) ±CI", "Mean Shifts", "Δ Shifts (%) ±CI")
println("  " * "─"^72)
for i in eachindex(SHIFT_COSTS)
    @printf("  %-12s │ %11.0f │ %+7.1f%% ±%5.1f%% │ %11.2f │ %+7.1f%% ±%5.1f%%\n",
            "$(SHIFT_COSTS[i]) €",
            mean_objs[i], Δobj_means[i], Δobj_cis[i],
            mean_shifts[i], Δshift_means[i], Δshift_cis[i])
end
println("  " * "─"^72)
@printf("  %-12s │ %11.0f │ %14s │ %11.2f │ %14s\n",
        "$(baseline) € (base)", base_obj, "—", base_shifts, "—")

# ── Plot ──────────────────────────────────────────────────────────────────────
p1 = plot(SHIFT_COSTS, Δobj_means,
    ribbon = Δobj_cis, fillalpha = 0.25,
    marker = :circle, markersize = 5, linewidth = 1.5,
    label = "Obj (95% CI)",
    xlabel = "Shifting cost (€/shift)", ylabel = "% change from baseline",
    title = "Shifting cost sensitivity — Deck A", dpi = 150)
hline!([0.0], linestyle = :dash, color = :grey, label = "baseline")

p2 = plot(SHIFT_COSTS, Δshift_means,
    ribbon = Δshift_cis, fillalpha = 0.25,
    marker = :square, markersize = 5, linewidth = 1.5, color = :green,
    label = "Shifts (95% CI)",
    xlabel = "Shifting cost (€/shift)", ylabel = "% change from baseline",
    title = "Shifts vs shifting cost — Deck A", dpi = 150)
hline!([0.0], linestyle = :dash, color = :grey, label = "baseline")

fig = plot(p1, p2, layout = (1, 2), size = (1000, 450))
savefig(fig, "sensitivity_shifting_cost_deckA.png")
println("\n  Saved: sensitivity_shifting_cost_deckA.png")

@printf("\nTotal runtime: %.1f s\n", time() - t_start)
