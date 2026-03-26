include("min_shifts.jl")
include("waiting_time.jl")

# 1500€ per cargo in revenue, 100€ per shift, 3000€/60 per minute waited. 

function evaluate_sol(deck, cargo_on; 
    mean_rev_cargo = 1500, 
    pcostshift = 100, 
    timecost = 3000/60,
    shift_evaluator="work_tot",
    handling_time = 4/60,
    num_operators = 5,
    percent_arrived=0.2,
    sol_details = false)

    c_on = [c for row in eachrow(cargo_on) for c in row if c !== nothing]
    totrev = sum([cargo.rev*mean_rev_cargo for cargo in c_on])
    wcost = wait_time(deck,cargo_on,handling_time=handling_time,num_operators=num_operators,percent_arrived=percent_arrived)*timecost
    if shift_evaluator == "work"
        shift_cost = min_shifts_work(deck)*pcostshift
    elseif shift_evaluator == "shifts"
        shift_cost = min_shifts(deck)*pcostshift

    elseif shift_evaluator == "shifts_tot"
        shift_cost = min_shift_all_cargo(deck)*pcostshift
        
    elseif shift_evaluator == "work_tot"
        shift_cost = min_shift_all_cargo_work(deck)*pcostshift
    end
    if sol_details
        (totrev, wcost, shift_cost)
    else
        return totrev - wcost - shift_cost
    end
end

