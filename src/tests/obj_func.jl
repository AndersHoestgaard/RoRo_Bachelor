include("min_shifts.jl")
include("waiting_time.jl")

# 1500€ per cargo in revenue, 100€ per shift, 3000€/60 per minute waited. 

function evaluate_sol(deck, cargo_on; mean_rev_cargo = 1500, pcostshift = 100, timecost = 3000/60,shift_evaluator="work_tot")
    c_on = [c for row in eachrow(cargo_on) for c in row if c !== nothing]
    totrev = sum([cargo.rev*mean_rev_cargo for cargo in c_on])
    wcost = wait_time(deck)*timecost
    if shift_evaluator == "work"
        shift_cost = min_shifts_work(deck)*pcostshift
    elseif shift_evaluator == "shifts"
        shift_cost = min_shifts(deck)*pcostshift

    elseif shift_evaluator == "shifts_tot"
        shift_cost = min_shift_all_cargo(deck)*pcostshift
        
    elseif shift_evaluator == "work_tot"
        shift_cost = min_shift_all_cargo_work(deck)*pcostshift
    end
    return totrev - wcost - shift_cost
end

function sol_details(deck, cargo_on; mean_rev_cargo = 1500, pcostshift = 100, timecost = 3000)
    totrev = sum([cargo.rev*mean_rev_cargo for cargo in cargo_on])
    wcost = wait_time(deck)*timecost
    shift_cost = min_shifts(deck)*pcostshift
    return (totrev, wcost, shift_cost)
end
