include(joinpath(pwd(), "src/cargo_generation.jl"))
include("obj_func.jl")

dir = joinpath(pwd(), "src/Heuristics")
jl_files = filter(f -> endswith(f, ".jl"), readdir(dir))
include.(joinpath.(dir, jl_files))





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

