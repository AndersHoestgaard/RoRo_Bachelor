include("min_shifts.jl")
include("waiting_time.jl")

function evaluate_sol(deck, cargo_on, mean_rev_cargo = 10, pcostshift = 1, timecost = 2)

    totrev = sum([cargo.rev*mean_rev_cargo for cargo in cargo_on])
    wcost = wait_time(deck)*timecost
    shift_cost = min_shifts(deck)*pcostshift
    return totrev - wcost - shift_cost
end


