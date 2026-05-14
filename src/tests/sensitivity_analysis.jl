t_load = time()
println("Loading dependencies...")

include(joinpath(pwd(), "src/Heuristics/load_random.jl"))
include(joinpath(pwd(), "src/tests/run_alns.jl"))

include(joinpath(pwd(), "src/Decks/DeckA.jl"))
include(joinpath(pwd(), "src/Decks/DeckB.jl"))
include(joinpath(pwd(), "src/Decks/DeckC.jl"))
include(joinpath(pwd(), "src/Decks/Tor_Magnolia_Decks.jl"))
include(joinpath(pwd(), "src/Cargo_instances/train_and_test_for_deckA.jl"))
include(joinpath(pwd(), "src/Cargo_instances/train_and_test_for_deckB.jl"))
include(joinpath(pwd(), "src/Cargo_instances/train_and_test_for_deckC.jl"))

using Statistics: mean, std
using Printf
using Plots
using Random

println("Loaded in $(round(time()-t_load, digits=2)) s\n")

# ── Baseline parameters ───────────────────────────────────────────────────────
const BASE_TIMECOST    = 500 / 60   # €/min (= 500 €/h)
const BASE_PCOSTSHIFT  = 250        # €/shift
const BASE_HANDLING    = 7          # min per cargo unit
const BASE_NUM_OPS     = 1          # tugmasters (matches MIP)

const SA_PATIENCE = 10000

test_set(arr) = arr[end-test_size+1:end]

# ── Sensitivity sweep definitions ─────────────────────────────────────────────
const SWEEPS = [
    (
        label     = "Revenue factor",
        xlabel    = "Revenue factor (× baseline)",
        values    = [0.50, 0.75, 1.00, 1.25, 1.50],
        inst_fn   = (insts, v) -> scale_cargo_rev(insts, v),
        kwargs_fn = v -> (;),
    ),
    (
        label     = "Fuel cost factor",
        xlabel    = "Fuel cost factor (× 500 €/h)",
        values    = [0.50, 0.75, 1.00, 1.25, 1.50],
        inst_fn   = (insts, v) -> insts,
        kwargs_fn = v -> (; timecost = v * BASE_TIMECOST),
    ),
    (
        label     = "Handling time",
        xlabel    = "Handling time (min/unit)",
        values    = [3, 5, 7, 10, 15, 20],
        inst_fn   = (insts, v) -> insts,
        kwargs_fn = v -> (; handling_time = v),
    ),
    (
        label     = "Mean inter-arrival time",
        xlabel    = "Mean inter-arrival time (min)",
        values    = [0.25, 0.5, 1.0, 2.0, 5.0, 15.0, 30.0],
        inst_fn   = (insts, v) -> rescale_arrivals(insts, v),
        kwargs_fn = v -> (;),
    ),
    (
        label     = "Number of tugmasters",
        xlabel    = "Tugmasters (#)",
        values    = [1, 2, 3, 4],
        inst_fn   = (insts, v) -> insts,
        kwargs_fn = v -> (; num_operators = v),
    ),
]

# ── Cargo helpers ─────────────────────────────────────────────────────────────

function scale_cargo_rev(instances, factor)
    return [[Cargo(c.type, c.port, c.arr, Float32(c.rev * factor)) for c in inst]
            for inst in instances]
end

function rescale_arrivals(instances, mean_minutes; p_arrived = 0.2, base_seed = 42)
    return [begin
        rng  = MersenneTwister(base_seed + k)
        n    = length(inst)
        arrs = generate_arrival_times_exp(n;
                   mean_minutes = mean_minutes,
                   p_arrived    = p_arrived,
                   rng          = rng)
        [Cargo(inst[i].type, inst[i].port, Float32(arrs[i]), inst[i].rev) for i in 1:n]
    end for (k, inst) in enumerate(instances)]
end

# ── Core runner ───────────────────────────────────────────────────────────────

function run_on_instances(deck, instances;
        timecost      = BASE_TIMECOST,
        pcostshift    = BASE_PCOSTSHIFT,
        handling_time = BASE_HANDLING,
        num_operators = BASE_NUM_OPS,
        patience      = SA_PATIENCE)

    obj_vals = Float64[]
    n_cargo  = Int[]
    n_shifts = Float64[]

    for cargo in instances
        d, c, _, _ = alns_hansen_basket(deck, cargo;
            timecost         = timecost,
            pcostshift       = pcostshift,
            handling_time    = handling_time,
            num_operators    = num_operators,
            early_stop_thres = patience,
            print_status     = false)

        push!(obj_vals, evaluate_sol(d, c;
            timecost      = timecost,
            pcostshift    = pcostshift,
            handling_time = handling_time,
            num_operators = num_operators))
        push!(n_cargo,  count(!isnothing, c))
        push!(n_shifts, min_shift_all_cargo_work(d))
    end

    return obj_vals, n_cargo, n_shifts
end

# ── CI helper ─────────────────────────────────────────────────────────────────

ci95(x) = length(x) > 1 ? 1.96 * std(x) / sqrt(length(x)) : 0.0

# ── Table printer ─────────────────────────────────────────────────────────────

function print_sweep_table(label, param_values,
                            mean_objs, mean_cargos, mean_shiftvals,
                            Δobj_means, Δobj_cis,
                            Δcargo_means, Δcargo_cis,
                            base_obj, base_cargo, base_shifts)
    println()
    println("  ┌─ $(label)")
    println("  " * "─"^92)
    @printf("  %-10s │ %11s │ %16s │ %10s │ %16s │ %10s\n",
            "Value", "Mean Obj (€)", "Δ Obj (%) ±CI", "Mean Cargo", "Δ Cargo (%) ±CI", "Mean Shifts")
    println("  " * "─"^92)
    for i in eachindex(param_values)
        @printf("  %-10s │ %11.0f │ %+8.1f%% ±%5.1f%% │ %10.2f │ %+8.1f%% ±%5.1f%% │ %10.2f\n",
                string(param_values[i]),
                mean_objs[i],
                Δobj_means[i], Δobj_cis[i],
                mean_cargos[i],
                Δcargo_means[i], Δcargo_cis[i],
                mean_shiftvals[i])
    end
    println("  " * "─"^92)
    @printf("  %-10s │ %11.0f │ %16s │ %10.2f │ %16s │ %10.2f\n",
            "baseline", base_obj, "—", base_cargo, "—", base_shifts)
    println()
end

# ── Plot results ──────────────────────────────────────────────────────────────

function plot_sensitivity_results(deck_name, all_sweep_results, save_prefix)
    plts = []
    for (sw, (Δobj_means, Δobj_cis, Δcargo_means, Δcargo_cis)) in zip(SWEEPS, all_sweep_results)
        xvals  = string.(sw.values)
        xticks = (1:length(xvals), xvals)

        p = plot(
            1:length(xvals), Δobj_means,
            ribbon    = Δobj_cis,
            fillalpha = 0.25,
            marker    = :circle, markersize = 5,
            linewidth = 1.5,
            label     = "Obj (95% CI)",
            xlabel    = sw.xlabel,
            ylabel    = "% change from baseline",
            title     = "$(sw.label) — Deck $deck_name",
            xticks    = xticks,
            legend    = :topright,
            dpi       = 150,
        )
        hline!([0.0], linestyle = :dash, color = :grey, label = "baseline")
        plot!(
            1:length(xvals), Δcargo_means,
            ribbon    = Δcargo_cis,
            fillalpha = 0.25,
            marker    = :square, markersize = 5,
            linewidth = 1.5,
            linestyle = :dash,
            label     = "Cargo (95% CI)",
        )
        push!(plts, p)
    end

    n     = length(plts)
    ncols = 3
    nrows = ceil(Int, n / ncols)
    fig   = plot(plts..., layout = (nrows, ncols), size = (1400, nrows * 420))
    fname = "$(save_prefix)_sensitivity_deck$(deck_name).png"
    savefig(fig, fname)
    println("  Saved: $fname")
    return fig
end

# ── Full analysis for one deck ────────────────────────────────────────────────

function sensitivity_analysis(deck, test_instances, deck_name; save_prefix = "results")
    n = length(test_instances)
    println("═"^70)
    println("  Sensitivity Analysis — Deck $deck_name   ($n test instances)")
    println("  Baseline: $(round(BASE_TIMECOST*60; digits=0)) €/h · " *
            "pcostshift=$(BASE_PCOSTSHIFT) € · " *
            "handling=$(BASE_HANDLING) min · " *
            "num_operators=$(BASE_NUM_OPS)")
    println("  ALNS patience=$(SA_PATIENCE), init=load_random")
    println("═"^70)

    base_objs, base_cargos, base_shifts_v = run_on_instances(deck, test_instances)
    base_obj    = mean(base_objs)
    base_cargo  = mean(base_cargos)
    base_shifts = mean(base_shifts_v)
    @printf("\n  Baseline:  mean obj = %.0f € (±%.0f)   mean cargo = %.2f (±%.2f)   mean shifts = %.2f\n",
            base_obj, ci95(base_objs), base_cargo, ci95(base_cargos), base_shifts)

    all_sweep_results = []

    for sw in SWEEPS
        println("\n  Running: $(sw.label)...")
        mean_obj_vals   = Float64[]
        mean_cargo_vals = Float64[]
        mean_shift_vals = Float64[]
        Δobj_means      = Float64[]
        Δobj_cis        = Float64[]
        Δcargo_means    = Float64[]
        Δcargo_cis      = Float64[]

        for v in sw.values
            print("    $(sw.label) = $v ...")
            objs, cargos, shifts = run_on_instances(deck, sw.inst_fn(test_instances, v);
                                                    sw.kwargs_fn(v)...)
            Δobj_i   = 100 .* (objs   .- base_obj)   ./ abs(base_obj)
            Δcargo_i = 100 .* (cargos .- base_cargo) ./ max(base_cargo, 1.0)
            push!(mean_obj_vals,   mean(objs))
            push!(mean_cargo_vals, mean(cargos))
            push!(mean_shift_vals, mean(shifts))
            push!(Δobj_means,      mean(Δobj_i))
            push!(Δobj_cis,        ci95(Δobj_i))
            push!(Δcargo_means,    mean(Δcargo_i))
            push!(Δcargo_cis,      ci95(Δcargo_i))
            @printf(" done  (Δobj %+.1f%%)\n", mean(Δobj_i))
        end

        print_sweep_table(sw.label, sw.values,
                          mean_obj_vals, mean_cargo_vals, mean_shift_vals,
                          Δobj_means, Δobj_cis,
                          Δcargo_means, Δcargo_cis,
                          base_obj, base_cargo, base_shifts)

        push!(all_sweep_results, (Δobj_means, Δobj_cis, Δcargo_means, Δcargo_cis))
    end

    plot_sensitivity_results(deck_name, all_sweep_results, save_prefix)
    println()
end

# ── Smoke test ────────────────────────────────────────────────────────────────

function smoke_test(deck, inst_pool, deck_name)
    println("── Smoke test — Deck $deck_name (1 instance, patience=50) ──")
    inst = [inst_pool[end]]

    base_objs, base_cargos, base_shifts_s = run_on_instances(deck, inst; patience = 50)
    @assert isfinite(base_objs[1]) "Baseline not finite: $(base_objs[1])"
    @printf("  baseline  obj = %.0f €, cargo = %.0f, shifts = %.2f  ✓\n",
            base_objs[1], base_cargos[1], base_shifts_s[1])

    rev_objs, _, _ = run_on_instances(deck, scale_cargo_rev(inst, 1.5); patience = 50)
    @assert isfinite(rev_objs[1]) "Scaled-revenue not finite"
    println("  rev × 1.5  ✓")

    arr_objs, _, _ = run_on_instances(deck, rescale_arrivals(inst, 30.0); patience = 50)
    @assert isfinite(arr_objs[1]) "Rescaled-arrival (30 min) not finite"
    println("  arrival 30 min  ✓")

    ops_objs, _, _ = run_on_instances(deck, inst; num_operators = 4, patience = 50)
    @assert isfinite(ops_objs[1]) "num_operators=4 not finite"
    println("  num_operators=4  ✓")

    println("  Generating preview plots with synthetic data...")
    rng_preview = MersenneTwister(1)
    dummy_results = [
        (
            10 .* randn(rng_preview, length(sw.values)),
            2  .* ones(length(sw.values)),
            3  .* randn(rng_preview, length(sw.values)),
            1  .* ones(length(sw.values)),
        )
        for sw in SWEEPS
    ]
    plot_sensitivity_results("$(deck_name)_preview", dummy_results, "smoke_test")
    println("── Smoke test passed ──\n")
end

# ── Entry point ───────────────────────────────────────────────────────────────

const DECK = length(ARGS) > 0 ? uppercase(strip(ARGS[1])) : "A"

if DECK == "A"
    _deck_mat   = deckAmat
    _inst_pool  = cargo_a_90_6
    _deck_label = "A"
elseif DECK == "B"
    _deck_mat   = magnoliaMainmat
    _inst_pool  = cargo_b_90_6
    _deck_label = "B"
elseif DECK == "C"
    _deck_mat   = deckCmat
    _inst_pool  = cargo_c_90_6
    _deck_label = "C"
else
    error("Unknown deck '$DECK'. Pass A, B, or C as command-line argument.")
end

smoke_test(_deck_mat, _inst_pool, _deck_label)

t_start = time()
sensitivity_analysis(_deck_mat, test_set(_inst_pool), _deck_label)
@printf("\nTotal runtime: %.1f s\n", time() - t_start)
