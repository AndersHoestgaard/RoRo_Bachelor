include(joinpath(pwd(),"src/Decks/DeckTorM.jl"))
include(joinpath(pwd(),"src/Cargo_instances/CargoTorM.jl"))
include(joinpath(pwd(),"src/tests/obj_func2.jl"))
include(joinpath(pwd(),"src/tests/run_alns.jl"))
include(joinpath(pwd(),"src/Utils/visualization.jl"))

deck = deckTorMmat
cargo = cargoTorM

# ── 1. Basisheuristikker ────────────────────────────────────────────
println("\n=== Basisheuristikker ===")
println("heuristik       | profit        | shifts | revenue    | wcost   | scost")

init_deck1, init_cargo1 = pri_rules1(copy(deck), copy(cargo))
local rev, w, s = sol_details(init_deck1, init_cargo1)
println("pri_rules1      | $(evaluate_sol(init_deck1,init_cargo1)) | $(min_shifts(init_deck1)) | $rev | $w | $s")

init_deck2, init_cargo2 = pri_rules2(copy(deck), copy(cargo))
local rev, w, s = sol_details(init_deck2, init_cargo2)
println("pri_rules2      | $(evaluate_sol(init_deck2,init_cargo2)) | $(min_shifts(init_deck2)) | $rev | $w | $s")

# ── 2. simulate_alns operator-sammenligning ─────────────────────────
println("\n=== simulate_alns: Operator-kombinationer (pcostshift=750, n=500) ===")
println("kombination           | profit        | shifts | revenue    | wcost   | scost")

configs = [
    (destroy_random,        repair_greedy,        "random+greedy      "),
    (destroy_random,        repair_neighbor_rand, "random+neighbor_rand"),
    (destroy_random,        repair_placement,     "random+placement   "),
    (destroy_port,          repair_greedy,        "port+greedy        "),
    (destroy_port,          repair_placement,     "port+placement     "),
    (destroy_shifting_cost, repair_greedy,        "shiftcost+greedy   "),
    (destroy_neighbor,      repair_greedy,        "neighbor+greedy    "),
]

best_configs = []
for (dest, rep, name) in configs
    local best_deck, best_cargo, ob_vals = simulate_alns(deck, cargo,
        destroyer=dest, repairer=rep, n_sim=500, pcostshift=750)
    local rev, wcost, scost = sol_details(best_deck, best_cargo)
    local profit = evaluate_sol(best_deck, best_cargo)
    local shifts = min_shifts(best_deck)
    println("$name | $profit | $shifts | $rev | $wcost | $scost")
    push!(best_configs, (name, ob_vals))
end

# Konvergensplot for simulate_alns operatorer
Plots.plot(title="simulate_alns: Operator konvergens", 
    xlabel="iterationer", ylabel="profit", legend=:bottomright)
for (name, vals) in best_configs
    Plots.plot!(1:length(vals), vals, label=strip(name))
end
Plots.savefig("operator_convergence.png")
println("Konvergensplot gemt som operator_convergence.png")

# ── 3. alns_hansen ──────────────────────────────────────────────────
println("\n=== alns_hansen (adaptiv, n=2000) ===")
println("kombination      | profit        | shifts | revenue    | wcost   | scost")

best_deck_h, best_cargo_h, history = alns_hansen(deck, cargo,
    destroy_ops = [destroy_neighbor, destroy_area, destroy_port,
                   destroy_random, destroy_shifting_cost],
    repair_ops  = [repair_greedy, repair_neighbor_rand,
                   repair_placement, repair_random],
    init        = pri_rules2,
    iterations  = 2000
)
rev_h, wcost_h, scost_h = sol_details(best_deck_h, best_cargo_h)
profit_h = evaluate_sol(best_deck_h, best_cargo_h)
shifts_h = min_shifts(best_deck_h)
println("alns_hansen      | $profit_h | $shifts_h | $rev_h | $wcost_h | $scost_h")

# Sammenlign konvergens
best_sim = best_configs[argmax([ob_vals[end] for (_, ob_vals) in best_configs])]
Plots.plot(1:length(best_sim[2]), best_sim[2],
    label="simulate_alns ($(strip(best_sim[1])))",
    xlabel="iterationer", ylabel="profit",
    title="simulate_alns vs alns_hansen konvergens")
Plots.plot!(1:length(history), history, label="alns_hansen")
Plots.savefig("alns_comparison.png")
println("Sammenligning gemt som alns_comparison.png")

# ── 4. Sensitivitetsanalyse på pcostshift ───────────────────────────
println("\n=== Sensitivitetsanalyse: pcostshift ===")
println("metode           | pcostshift | profit        | shifts")

shift_costs = [20, 100, 250, 500, 750, 1000]
sens_sim_profits  = []
sens_sim_shifts   = []
sens_hans_profits = []
sens_hans_shifts  = []

for pc in shift_costs
    local best_deck, best_cargo, _ = simulate_alns(deck, cargo,
        destroyer=destroy_port, repairer=repair_greedy,
        n_sim=500, pcostshift=pc)
    local profit = evaluate_sol(best_deck, best_cargo, pcostshift=pc)
    local shifts = min_shifts(best_deck)
    println("simulate_alns    | $pc | $profit | $shifts")
    push!(sens_sim_profits, profit)
    push!(sens_sim_shifts, shifts)

    local bd_h, bc_h, _ = alns_hansen(deck, cargo,  # 3 værdier nu
        init=pri_rules2, iterations=1000)
    local profit_h = evaluate_sol(bd_h, bc_h, pcostshift=pc)
    local shifts_h = min_shifts(bd_h)
    println("alns_hansen      | $pc | $profit_h | $shifts_h")
    push!(sens_hans_profits, profit_h)
    push!(sens_hans_shifts, shifts_h)
end

# Sensitivitetsplot - shifts
Plots.plot(shift_costs, sens_sim_shifts, label="simulate_alns",
    marker=:circle, xlabel="pcostshift (€)", ylabel="antal shifts",
    title="Sensitivitet: pcostshift vs shifts")
Plots.plot!(shift_costs, sens_hans_shifts, label="alns_hansen", marker=:square)
Plots.savefig("sensitivity_shifts.png")

# Sensitivitetsplot - profit
Plots.plot(shift_costs, sens_sim_profits, label="simulate_alns",
    marker=:circle, xlabel="pcostshift (€)", ylabel="profit (€)",
    title="Sensitivitet: pcostshift vs profit")
Plots.plot!(shift_costs, sens_hans_profits, label="alns_hansen", marker=:square)
Plots.savefig("sensitivity_profit.png")

println("\nFINISHED!")