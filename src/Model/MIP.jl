# ============================================================
# test_mip_continuous.jl
# Run from project root
# MIP with continuous delay penalty matching obj_func.jl
# Fix: removed j == ncols && continue to allow arcs to ramp
# Sequential handling: only 1 cargo at a time
# Objective: revenue - timecost * Dep[1] - shift cost
# No perfect wait time — charge full departure time
# ============================================================

using JuMP, HiGHS, Distributions, Random, Graphs,
      SimpleWeightedGraphs, StatsBase, Printf, Statistics
import MathOptInterface as MOI

include(joinpath(pwd(), "src/deck_representation.jl"))
include(joinpath(pwd(), "src/cargo_generation.jl"))
include(joinpath(pwd(), "src/tests/min_shifts.jl"))
include(joinpath(pwd(), "src/tests/waiting_time.jl"))
include(joinpath(pwd(), "src/tests/obj_func.jl"))
include(joinpath(pwd(), "src/Heuristics/load_random.jl"))

# --- Deck A ---
w, l  = 7, 10
unava = [[1,10],[2,10],[6,10],[7,10]]
ramp  = [[3,10],[4,10],[5,10]]
deckAstruct = Deck(w, l, unava, ramp)
deckAmat    = create_deck(deckAstruct)

# ============================================================
# MIP instance builder
# ============================================================
nrows = 7
ncols = 10

function build_mip_from_cargo(cargo_list, h_val;
        pcostshift = 250,
        timecost   = 500/60)

    unava     = Set([(1,10),(2,10),(6,10),(7,10)])
    ramp      = [(3,10),(4,10),(5,10)]
    S         = [(i,j) for i in 1:nrows for j in 1:ncols if !((i,j) in unava)]
    E         = ramp
    S_no_exit = [s for s in S if !(s in E)]

    max_heur_port = maximum(c.port for c in cargo_list)
    num_ports     = max_heur_port - 2
    P             = collect(1:num_ports+1)
    C             = collect(1:length(cargo_list))

    A     = Tuple{Tuple{Int,Int},Tuple{Int,Int}}[]
    Gamma = Dict{Tuple{Tuple{Int,Int},Tuple{Int,Int}},Vector{Tuple{Int,Int}}}()

    for (i,j) in S
        # East
        t = (i, j+1)
        if j+1 <= ncols && t in S
            push!(A, ((i,j), t))
            Gamma[((i,j), t)] = [(i, j+1)]
        end

        # West
        t = (i, j-1)
        if j-1 >= 1 && t in S
            push!(A, ((i,j), t))
            cl = Tuple{Int,Int}[]
            (i,j-1) in S && push!(cl, (i,j-1))
            j+1 <= ncols && (i,j+1) in S && push!(cl, (i,j+1))
            Gamma[((i,j), t)] = cl
        end

        # North-East
        if i > 1 && j+1 <= ncols
            t = (i-1, j+1)
            if t in S && (i-1,j) in S && (i,j+1) in S
                push!(A, ((i,j), t))
                cl = Tuple{Int,Int}[]
                (i-1,j)   in S && push!(cl, (i-1,j))
                (i-1,j+1) in S && push!(cl, (i-1,j+1))
                (i,  j+1) in S && push!(cl, (i,  j+1))
                Gamma[((i,j), t)] = cl
            end
        end

        # South-East
        if i < nrows && j+1 <= ncols
            t = (i+1, j+1)
            if t in S && (i+1,j) in S && (i,j+1) in S
                push!(A, ((i,j), t))
                cl = Tuple{Int,Int}[]
                (i+1,j)   in S && push!(cl, (i+1,j))
                (i+1,j+1) in S && push!(cl, (i+1,j+1))
                (i,  j+1) in S && push!(cl, (i,  j+1))
                Gamma[((i,j), t)] = cl
            end
        end

        # South
        if i < nrows && j >= 1 && j-1 >= 1
            t = (i+1, j)
            if t in S && j+1 <= ncols && (i,j+1) in S && (i,j-1) in S && (i+1,j-1) in S
                push!(A, ((i,j), t))
                cl = Tuple{Int,Int}[]
                (i+1,j)   in S && push!(cl, (i+1,j))
                (i,  j-1) in S && push!(cl, (i,  j-1))
                (i+1,j-1) in S && push!(cl, (i+1,j-1))
                Gamma[((i,j), t)] = cl
            end
        end

        # North
        if i > 1 && j >= 1 && j-1 >= 1
            t = (i-1, j)
            if t in S && j+1 <= ncols && (i,j+1) in S && (i,j-1) in S && (i-1,j-1) in S
                push!(A, ((i,j), t))
                cl = Tuple{Int,Int}[]
                (i-1,j)   in S && push!(cl, (i-1,j))
                (i,  j-1) in S && push!(cl, (i,  j-1))
                (i-1,j-1) in S && push!(cl, (i-1,j-1))
                Gamma[((i,j), t)] = cl
            end
        end
    end

    L  = Dict(c => 1                          for c in C)
    U  = Dict(c => cargo_list[c].port - 1     for c in C)
    Ac = Dict(c => Float64(cargo_list[c].arr) for c in C)
    h  = Dict(c => h_val                      for c in C)
    r  = Dict(c => Float64(cargo_list[c].rev) for c in C)
    R  = Dict(c => 1                          for c in C)

    C_load   = Dict(p => [c for c in C if L[c]==p] for p in P)
    C_unload = Dict(p => [c for c in C if U[c]==p] for p in P)

    M = maximum(values(Ac)) + length(cargo_list) * h_val + 1000.0

    return (S=S, E=E, S_no_exit=S_no_exit, P=P, C=C, A=A, Gamma=Gamma,
            L=L, U=U, Ac=Ac, h=h, r=r, R=R,
            C_load=C_load, C_unload=C_unload,
            C_shift=pcostshift, timecost=timecost, M=M,
            num_ports=num_ports)
end

# ============================================================
# MIP solver
# Objective: revenue - timecost * Dep[1] - shift cost
# Sequential handling: only 1 cargo at a time
# 1 hour time limit
# ============================================================
function solve_mip_continuous(inst; verbose=false)
    (;S,E,S_no_exit,P,C,A,Gamma,L,U,Ac,h,r,R,
      C_load,C_unload,C_shift,timecost,M) = inst

    model = Model(HiGHS.Optimizer); set_silent(model)
    set_optimizer_attribute(model, "time_limit", 3600.0)

    @variable(model, y[C], Bin)
    @variable(model, x[C,S], Bin)
    @variable(model, delta[C,S,P], Bin)
    @variable(model, d[C,S,P])
    @variable(model, f[C,A,P] >= 0)
    @variable(model, ST[C,P] >= 0)
    @variable(model, Dep[1:1] >= 0)
    @variable(model, z[C,C], Bin)

    @constraint(model,[c in C,a in A,p in P],
        f[c,a,p] <= R[c]*y[c])

    @objective(model, Max,
        sum(r[c]*y[c] for c in C)
        - timecost * Dep[1]
        - C_shift * sum(delta[c,s,p] for c in C,s in S,p in P))

    @constraint(model,[c in C],
        sum(x[c,s] for s in S) == R[c]*y[c])
    @constraint(model,[s in S],
        sum(x[c,s] for c in C) <= 1)
    @constraint(model,[c in C,s in S,p in P],
        delta[c,s,p] <= x[c,s])

    @constraint(model,[c in C],
        sum(d[c,e,L[c]] for e in E) <= R[c]*y[c])
    @constraint(model,[c in C,s in S_no_exit],
        d[c,s,L[c]] == -x[c,s])
    @constraint(model,[c in C],
        sum(d[c,e,U[c]] for e in E) >= -R[c]*y[c])
    @constraint(model,[c in C,s in S_no_exit],
        d[c,s,U[c]] == x[c,s])

    @constraint(model,[c in C,p in P,s in S],
        sum(f[c,a,p] for a in A if a[2]==s) -
        sum(f[c,a,p] for a in A if a[1]==s) == d[c,s,p])

    for p in P, c in C, dc in C
        c==dc && continue
        U[dc] < p && continue
        for s in S
            flow_in = [a for a in A if a[2]==s]
            cl_arcs = [a for a in A if s in Gamma[a]]
            @constraint(model,
                sum(f[c,a,p] for a in flow_in) +
                sum(f[c,a,p] for a in cl_arcs) <=
                M*(1-x[dc,s]+delta[dc,s,p]))
        end
    end

    @constraint(model,[c in C],
        ST[c,L[c]] >= Ac[c] - M*(1-y[c]))

    for c1 in C, c2 in C
        c1 == c2 && continue
        @constraint(model, z[c1,c2] + z[c2,c1] == 1)
        @constraint(model,
            ST[c2,L[c2]] >= ST[c1,L[c1]] + h[c1] - M*(1-z[c1,c2]))
        @constraint(model,
            ST[c1,L[c1]] >= ST[c2,L[c2]] + h[c2] - M*(1-z[c2,c1]))
    end

    for c in C_load[1]
        @constraint(model, Dep[1] >= ST[c,1]+h[c])
    end

    t_start = time()
    optimize!(model)
    t_mip   = round(time()-t_start, digits=2)
    status  = termination_status(model)

    if primal_status(model) == MOI.FEASIBLE_POINT
        obj        = objective_value(model)
        bound      = objective_bound(model)
        gap        = abs(bound - obj) / max(abs(obj), 1e-6) * 100
        n_accepted = sum(value(y[c])>0.5 ? 1 : 0 for c in C)
        n_shifts   = sum(value(delta[c,s,p])>0.5 ? 1 : 0
                         for c in C,s in S,p in P)
        dep1       = value(Dep[1])

        if verbose
            println("\nCargo decisions:")
            for c in C
                if value(y[c])>0.5
                    slots=[s for s in S if value(x[c,s])>0.5]
                    println("  Cargo $c → accepted, slot: $slots, port: $(U[c]), arr: $(round(Ac[c],digits=2)), rev: $(r[c])")
                else
                    println("  Cargo $c → rejected, port: $(U[c]), arr: $(round(Ac[c],digits=2)), rev: $(r[c])")
                end
            end
            println("\nHandling order:")
            accepted     = [c for c in C if value(y[c])>0.5]
            sorted_by_st = sort(accepted, by=c->value(ST[c,L[c]]))
            for c in sorted_by_st
                println("  Cargo $c: start=$(round(value(ST[c,L[c]]),digits=2)) min, ",
                    "finish=$(round(value(ST[c,L[c]])+h[c],digits=2)) min, ",
                    "arr=$(round(Ac[c],digits=2)) min")
            end
            println("\nDeparture time:")
            println("  Port 1: $(round(dep1,digits=2)) min")
            println("\nObjective breakdown:")
            rev        = sum(r[c] for c in C if value(y[c])>0.5)
            dep_cost   = round(timecost * dep1, digits=2)
            shift_cost = round(C_shift * n_shifts, digits=2)
            println("  Revenue:    $(round(rev,digits=2))€")
            println("  Dep[1]:     $(round(dep1,digits=2)) min")
            println("  Dep cost:   $(dep_cost)€")
            println("  Shifts:     $n_shifts")
            println("  Shift cost: $(shift_cost)€")
            println("  Total obj:  $(round(obj,digits=2))€")
            println("  Bound:      $(round(bound,digits=2))€")
            println("  Gap:        $(round(gap,digits=2))%")
            println("  Status:     $status")
        end

        return (obj=obj, bound=bound, gap=gap,
                n_accepted=n_accepted, n_shifts=n_shifts,
                dep1=dep1, status=status, time=t_mip), model
    end

    return (obj=nothing, bound=nothing, gap=nothing,
            n_accepted=0, n_shifts=0,
            dep1=0.0, status=status, time=t_mip), model
end

# ============================================================
# Run on instances
# ============================================================
function run_mip_on_instances(instances, label; h_val=7, verbose=false)
    println("="^115)
    println("MIP — $label")
    println("Parameters: timecost=500/60 €/min, C_shift=250, handling_time=$(h_val) min")
    println("="^115)
    @printf("%-12s  %10s  %10s  %8s  %8s  %8s  %10s  %8s  %12s\n",
        "Instance", "MIP Obj", "Bound", "Gap(%)", "Acc", "Shifts",
        "Dep cost", "Time (s)", "Status")
    println("-"^115)

    obj_vals   = Float64[]
    times      = Float64[]
    acc_vals   = Int[]
    shift_vals = Int[]

    for (i, cargo) in enumerate(instances)
        inst = build_mip_from_cargo(cargo, h_val,
            pcostshift=250, timecost=500/60)
        mip_result, _ = solve_mip_continuous(inst, verbose=verbose)

        if mip_result.obj !== nothing
            rev      = sum(inst.r[c] for c in inst.C)
            dep_cost = round((500/60)*mip_result.dep1, digits=2)
            @printf("%-12s  %10.2f  %10.2f  %7.2f%%  %8d  %8d  %10.2f  %8.2f  %12s\n",
                "inst $i",
                mip_result.obj,
                mip_result.bound,
                mip_result.gap,
                mip_result.n_accepted,
                mip_result.n_shifts,
                dep_cost,
                mip_result.time,
                string(mip_result.status))
            println("  ↳ Dep[1]: $(round(mip_result.dep1,digits=2)) min")
            push!(obj_vals,   mip_result.obj)
            push!(times,      mip_result.time)
            push!(acc_vals,   mip_result.n_accepted)
            push!(shift_vals, mip_result.n_shifts)
        else
            @printf("%-12s  %10s  %10s  %8s  %8d  %8d  %10s  %8.2f  %12s\n",
                "inst $i", "-", "-", "-",
                0, 0, "-", mip_result.time,
                string(mip_result.status))
            push!(obj_vals,   NaN)
            push!(times,      mip_result.time)
            push!(acc_vals,   0)
            push!(shift_vals, 0)
        end
    end

    println("="^115)
    println("Summary:")
    valid = filter(!isnan, obj_vals)
    @printf("  Mean obj:      %.2f\n", isempty(valid) ? 0.0 : mean(valid))
    @printf("  Mean time:     %.2f s\n", mean(times))
    @printf("  Mean accepted: %.1f / %d\n", mean(acc_vals), length(instances[1]))
    @printf("  Mean shifts:   %.2f\n", mean(shift_vals))
    println("="^115)

    return obj_vals, times, acc_vals, shift_vals
end

# ============================================================
# Sweep: 5, 10, 15, 20, 25, 30, 35 cargo
# 5 instances per size, seed 1:5, num_ports=6, h=7
# 1 hour time limit per instance
# ============================================================
println("="^115)
println("Cargo size sweep: n = 5, 10, 15, 20, 25, 30, 35")
println("5 instances per size, seed 1:5, num_ports=6, h=7, time limit=3600s")
println("="^115)
@printf("%-8s  %-10s  %10s  %10s  %7s  %8s  %8s  %10s  %8s  %12s\n",
    "n", "Instance", "MIP Obj", "Bound", "Gap(%)",
    "Acc", "Shifts", "Dep[1]", "Time(s)", "Status")
println("-"^115)

for n in [5, 10, 15, 20, 25, 30, 35]
    cargo  = genereate_cargo_structs(n, seed=n, num_ports=6)
    inst   = build_mip_from_cargo(cargo, 7, pcostshift=250, timecost=500/60)
    result, _ = solve_mip_continuous(inst, verbose=false)
    if result.obj !== nothing
        @printf("%-8d  %-10s  %10.2f  %10.2f  %6.2f%%  %8d  %8d  %10.2f  %8.2f  %12s\n",
            n, "seed $n",
            result.obj, result.bound, result.gap,
            result.n_accepted, result.n_shifts,
            result.dep1, result.time, string(result.status))
    else
        @printf("%-8d  %-10s  %10s  %10s  %7s  %8d  %8d  %10s  %8.2f  %12s\n",
            n, "seed $n",
            "-", "-", "-", 0, 0, "-",
            result.time, string(result.status))
    end
    println("-"^115)
end
println("="^115)

println("\n--- Verbose run: n=5, seed=1 ---")
let cargo = genereate_cargo_structs(5, seed=1, num_ports=6)
    inst = build_mip_from_cargo(cargo, 7, pcostshift=250, timecost=500/60)
    solve_mip_continuous(inst, verbose=true)
end