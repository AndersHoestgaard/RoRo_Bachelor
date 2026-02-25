include(joinpath(pwd(), "src/Decks/DeckC.jl"))
include(joinpath(pwd(), "src/Cargo_instances/CargoC.jl"))
include(joinpath(pwd(), "src/tests/obj_func.jl"))

deck = deckCmat
cargo = cargoC

println("Shifts: ", min_shifts(deck))
println("Waiting time: ", wait_time(cargo))
println("Profit: ", evaluate_sol(deck, cargo))

rev, wcost, scost = sol_details(deck, cargo)

println("Revenue:      ", rev)
println("Waiting cost: ", wcost)
println("Shift cost:   ", scost)
println("Profit:       ", rev - wcost - scost)

'Results:
Shifts: 0
Waiting time: 340.3873609304428
Profit: -571766.84375

Revenue:      508233.16
Waiting cost: 1.08e6
Shift cost:   0
Profit:       -571766.84375'