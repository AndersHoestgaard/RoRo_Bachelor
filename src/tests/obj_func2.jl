include("min_shifts.jl")
include("waiting_time.jl")

# 7500€ per cargo in revenue, 750€ per shift, 265€ per hour waited.

function evaluate_sol(deck, cargo_on; mean_rev_cargo = 7500, pcostshift = 750, timecost = 265, shift_evaluator="work")
    c_on = [c for row in eachrow(cargo_on) for c in row if c !== nothing]
    totrev = sum(cargo.rev * mean_rev_cargo for cargo in c_on)
    arr_times = [c.arr for c in c_on]  # Changed - Anders
    wcost = wait_time(arr_times) * timecost
    if shift_evaluator == "work"
        shift_cost = min_shifts_work(deck) * pcostshift
    elseif shift_evaluator == "shifts"
        shift_cost = min_shifts(deck) * pcostshift
    elseif shift_evaluator == "shifts_tot"
        shift_cost = min_shift_all_cargo(deck) * pcostshift
    elseif shift_evaluator == "work_tot"
        shift_cost = min_shift_all_cargo_work(deck) * pcostshift
    end
    return totrev - wcost - shift_cost
end

function sol_details(deck, cargo_on; mean_rev_cargo = 7500, pcostshift = 750, timecost = 265)
    c_on = [c for row in eachrow(cargo_on) for c in row if c !== nothing]
    totrev = sum(c.rev * mean_rev_cargo for c in c_on)
    arr_times = [c.arr for c in c_on]  # Changed - Anders
    wcost = wait_time(arr_times) * timecost
    shift_cost = min_shifts(deck) * pcostshift
    return (totrev, wcost, shift_cost)
end
