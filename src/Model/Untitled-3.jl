# ============================================================
# test_mip_continuous.jl
# Run from project root
# MIP with continuous delay penalty matching obj_func.jl
# Fix: removed j == ncols && continue to allow arcs to ramp
# Sequential handling: only 1 cargo handled at a time
# ============================================================

using JuMP, HiGHS, Distributions, Random, Graphs,
      SimpleWeightedGraphs, StatsBase, Printf, Statistics

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
            Gamma[((i,j), t)] = Tuple{Int,Int}[]
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
# Sequential handling: only 1 cargo at a time
# ============================================================
function solve_mip_continuous(inst, perfect_wt; verbose=false)
    (;S,E,S_no_exit,P,C,A,Gamma,L,U,Ac,h,r,R,
      C_load,C_unload,C_shift,timecost,M) = inst

    model = Model(HiGHS.Optimizer); set_silent(model)

    @variable(model, y[C], Bin)
    @variable(model, x[C,S], Bin)
    @variable(model, delta[C,S,P], Bin)
    @variable(model, d[C,S,P])
    @variable(model, f[C,A,P] >= 0)
    @variable(model, ST[C,P] >= 0)
    @variable(model, Dep[P] >= 0)
    @variable(model, delay >= 0)
    # binary variable: z[c1,c2] = 1 if c1 handled before c2
    @variable(model, z[C,C], Bin)

    @constraint(model,[c in C,a in A,p in P],
        f[c,a,p] <= R[c]*y[c])

    @objective(model, Max,
        sum(r[c]*y[c] for c in C)
        - timecost * delay
        - C_shift * sum(delta[c,s,p] for c in C,s in S,p in P))

    @constraint(model, delay >= Dep[first(P)] - perfect_wt)

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

    # arrival time constraint
    @constraint(model,[c in C],
        ST[c,L[c]] >= Ac[c] - M*(1-y[c]))

    # sequential handling — only 1 cargo at a time
    # z[c1,c2] = 1 means c1 is handled before c2
    for c1 in C, c2 in C
        c1 == c2 && continue
        # z[c1,c2] + z[c2,c1] == 1 — one must come before the other
        @constraint(model, z[c1,c2] + z[c2,c1] == 1)
        # if c1 before c2: ST[c2] >= ST[c1] + h[c1] - M*(1-z[c1,c2])
        @constraint(model,
            ST[c2,L[c2]] >= ST[c1,L[c1]] + h[c1] - M*(1-z[c1,c2]))
        # if c2 before c1: ST[c1] >= ST[c2] + h[c2] - M*(1-z[c2,c1])
        @constraint(model,
            ST[c1,L[c1]] >= ST[c2,L[c2]] + h[c2] - M*(1-z[c2,c1]))
    end

    for p in P, c in union(C_load[p],C_unload[p])
        @constraint(model, Dep[p] >= ST[c,p]+h[c])
    end
    @constraint(model,[p in 1:length(P)-1],
        Dep[P[p+1]] >= Dep[P[p]])

    t_start = time()
    optimize!(model)
    t_mip   = round(time()-t_start, digits=2)
    status  = termination_status(model)

    if status == OPTIMAL
        obj        = objective_value(model)
        n_accepted = sum(value(y[c])>0.5 ? 1 : 0 for c in C)
        n_shifts   = sum(value(delta[c,s,p])>0.5 ? 1 : 0
                         for c in C,s in S,p in P)
        dep1      = value(Dep[first(P)])
        delay_val = value(delay)

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
            accepted = [c for c in C if value(y[c])>0.5]
            sorted_by_st = sort(accepted, by=c->value(ST[c,L[c]]))
            for c in sorted_by_st
                println("  Cargo $c: start=$(round(value(ST[c,L[c]]),digits=2)) min, finish=$(round(value(ST[c,L[c]])+h[c],digits=2)) min, arr=$(round(Ac[c],digits=2)) min")
            end
            println("\nDeparture times:")
            for p in P
                println("  Port $p: $(round(value(Dep[p]),digits=2)) min")
            end
            println("\nObjective breakdown:")
            rev = sum(r[c] for c in C if value(y[c])>0.5)
            println("  Revenue:    $(round(rev,digits=2))€")
            println("  Delay:      $(round(delay_val,digits=2)) min")
            println("  Delay cost: $(round(timecost*delay_val,digits=2))€")
            println("  Shifts:     $n_shifts")
            println("  Shift cost: $(round(C_shift*n_shifts,digits=2))€")
            println("  Total obj:  $(round(obj,digits=2))€")
        end

        return (obj=obj, n_accepted=n_accepted, n_shifts=n_shifts,
                dep1=dep1, delay=delay_val,
                status=status, time=t_mip), model
    else
        return (obj=nothing, n_accepted=0, n_shifts=0,
                dep1=0.0, delay=0.0,
                status=status, time=t_mip), model
    end
end

# ============================================================
# Run on instances
# ============================================================
function run_mip_on_instances(instances, label; h_val=7, verbose=false)
    println("="^90)
    println("MIP — Continuous delay penalty — $label")
    println("Parameters: timecost=500/60 €/min, C_shift=250, handling_time=$(h_val) min")
    println("="^90)
    @printf("%-12s  %10s  %8s  %8s  %10s  %10s  %8s\n",
        "Instance", "MIP Obj", "Acc", "Shifts",
        "Revenue", "Delay cost", "Time (s)")
    println("-"^90)

    obj_vals   = Float64[]
    times      = Float64[]
    acc_vals   = Int[]
    shift_vals = Int[]

    for (i, cargo) in enumerate(instances)
        inst = build_mip_from_cargo(cargo, h_val,
            pcostshift=250, timecost=500/60)
        tmp_deck, tmp_cargo_on = load_random(copy(deckAmat), copy(cargo))
        perfect_wt = perfect_wait_time(tmp_deck, tmp_cargo_on)
        mip_result, _ = solve_mip_continuous(inst, perfect_wt,
                             verbose=verbose)

        if mip_result.obj !== nothing
            rev        = sum(inst.r[c] for c in inst.C)
            delay_cost = round((500/60)*mip_result.delay, digits=2)
            @printf("%-12s  %10.2f  %8d  %8d  %10.2f  %10.2f  %8.2f\n",
                "inst $i",
                mip_result.obj,
                mip_result.n_accepted,
                mip_result.n_shifts,
                rev,
                delay_cost,
                mip_result.time)
            println("  ↳ PWT: $(round(perfect_wt,digits=2)) min  |  Delay: $(round(mip_result.delay,digits=2)) min")
            push!(obj_vals,   mip_result.obj)
            push!(times,      mip_result.time)
            push!(acc_vals,   mip_result.n_accepted)
            push!(shift_vals, mip_result.n_shifts)
        else
            @printf("%-12s  %10s  %8d  %8d  %10s  %10s  %8.2f\n",
                "inst $i", "INFEASIBLE",
                0, 0, "-", "-", mip_result.time)
            push!(obj_vals,   NaN)
            push!(times,      mip_result.time)
            push!(acc_vals,   0)
            push!(shift_vals, 0)
        end
    end

    println("="^90)
    println("Summary:")
    valid = filter(!isnan, obj_vals)
    @printf("  Mean obj:      %.2f\n", isempty(valid) ? 0.0 : mean(valid))
    @printf("  Mean time:     %.2f s\n", mean(times))
    @printf("  Mean accepted: %.1f / %d\n", mean(acc_vals), length(instances[1]))
    @printf("  Mean shifts:   %.2f\n", mean(shift_vals))
    println("="^90)

    return obj_vals, times, acc_vals, shift_vals
end

# ============================================================
# Training instances — DeckA 20 cargo 6 ports
# ============================================================
Random.seed!(4242)
trainsize  = 20
seedstrain = [rand(1:10000) for i in 1:trainsize]
deckA20    = [genereate_cargo_structs(floor(Int,20), seed=i, num_ports=6) for i in seedstrain]

# --- run first instance with first 5 cargo ---
run_mip_on_instances([deckA20[1][1:5]], "DeckA 5 cargo 6 ports", h_val=7, verbose=true)