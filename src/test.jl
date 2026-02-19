include("Utils/min_shifts.jl")
include("Utils/waiting_time.jl")

function evaluate_sol(deck, cargo_on, mean_rev_cargo = 10, pcostshift = 1, timecost = 2)
    return sum([cargo[4]*mean_rev_cargo for cargo in cargo_on]) - wait_time(deck)*timecost - min_shifts(deck)*pcostshift
end


