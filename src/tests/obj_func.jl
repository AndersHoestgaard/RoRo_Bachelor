include("min_shifts.jl")
include("waiting_time.jl")


function evaluate_sol(deck, cargo_on; 
    pcostshift = 250, 
    timecost = 500/60,
    shift_evaluator="work_tot",
    handling_time = 7,
    num_operators = 1,
    sol_details = false,)

    deck = deepcopy(deck)
    cargo_on = deepcopy(cargo_on)
    c_on = [c for row in eachrow(cargo_on) for c in row if c !== nothing]
    if isempty(c_on) 
        totrev = 0
    else
        totrev = sum([cargo.rev for cargo in c_on])
    end
    wcost = wait_time(deck,cargo_on,handling_time=handling_time,num_operators=num_operators)*timecost
    
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
        return (totrev, wcost, shift_cost)
    else
        return totrev - wcost - shift_cost
    end
end

