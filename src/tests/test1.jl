include(joinpath(pwd(), "src/cargo_generation.jl"))
include("obj_func.jl")


## Simulates solution method (heuristic) iteratively on random cargo with no var. on amount of cargo. 
function test1(sol_method, deck, n_cargo, n_sim) 
    obj_vals = []

    for i in 1:n_sim
        deckcopy = copy(deck)
        cargo = genereate_cargo_structs(n_cargo)
        (sol,cargo_on) = sol_method(deckcopy,cargo)
        obv = evaluate_sol(sol,cargo_on)
        push!(obj_vals,obv)

    end
    return obj_vals
end

function test2(sol_method, deck, mu_cargo, n_sim; std_cargo = 5) 
    obj_vals = []

    for i in 1:n_sim
        deckcopy = copy(deck)
        cargo = genereate_cargo_structs(2)
        (sol,cargo_on) = sol_method(deckcopy,cargo)
        obv = evaluate_sol(sol,cargo_on)
        push!(obj_vals,obv)

    end
    return obj_vals
end