include("min_shifts.jl")
include("waiting_time.jl")

## 1500€ per cargo in revenue, 100€ per shift, 3000€ per hour waited. 

function evaluate_sol(deck, cargo_on, mean_rev_cargo = 1500, pcostshift = 100, timecost = 3000)

    totrev = sum([cargo.rev*mean_rev_cargo for cargo in cargo_on])
    wcost = wait_time(deck)*timecost
    shift_cost = min_shifts(deck)*pcostshift
    return totrev - wcost - shift_cost
end
