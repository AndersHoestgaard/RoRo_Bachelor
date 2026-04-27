include("min_shifts.jl")
include("waiting_time.jl")


function evaluate_sol(deck, cargo_on; 
    pcostshift = 250, 
    timecost = 500/60,
    shift_evaluator="work_tot",
    handling_time = 7,
    num_operators = 5,
    sol_details = false,
    normalised=false,
    norms = [1,1,1],
    priority = [0.50,0.3,0.2])

    deck = deepcopy(deck)
    cargo_on = deepcopy(cargo_on)
    c_on = [c for row in eachrow(cargo_on) for c in row if c !== nothing]
    if isempty(c_on) 
        totrev = 0
    else
        totrev = sum([cargo.rev for cargo in c_on])
    end
    wcost = maximum([0,wait_time(deck,cargo_on,handling_time=handling_time,num_operators=num_operators)-perfect_wait_time(deck,cargo_on)])*timecost
    
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
    elseif normalised
        normrev,normwait,normshift = norms
        p1,p2,p3 = priority
        #println(totrev/normrev)
        #println(wcost/normwait )
        #println(shift_cost/normshift)
        #println(min_shift_all_cargo_work(deck),"   ",pcostshift)

        if shift_cost == Inf
            display(deck)
        end
        if wcost == Inf
            display(deck)
        end

        return p1*totrev/normrev - p2*wcost/max(0.001,normwait) - p3*shift_cost/maximum([1,normshift])
    else
        return totrev - wcost - shift_cost
    end
end

