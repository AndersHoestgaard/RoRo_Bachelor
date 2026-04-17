using Random, Distributions
function generate_cargo_type(n;rng = nothing)
    if rng !== nothing
        return rand(rng,["car" "truck" "machinery" "container"],n)
    else
        return rand(["car" "truck" "machinery" "container"],n)
    end
end

function generate_cargo_port(n; num_ports=5, rng = nothing)
    if rng !== nothing 
        return rand(rng,[i for i in 3:num_ports+2],n)
    else
        return rand([i for i in 3:num_ports+2],n)
    end
end 

function generate_arrival_times_exp(n;p_arrived=0.2,lambd=1/60, rng=nothing)
    if rng !== nothing
        i_times = [rand(rng,Exponential(lambd)) for _ in 1:n]
        i_times[1:Int(round(p_arrived*n))] = 0.02
        return cumsum(i_times)
    else
        i_times = [rand(Exponential(lambd)) for _ in 1:n]
        i_times[1:Int(round(p_arrived*n))] = 0.02
        return cumsum(i_times)
    end
end

function generate_rev(n;pricelist = [1200,1400,1500,1600,1700],rng = nothing)
    if rng !== nothing
        return [rand(rng,pricelist) for _ in 1:n]
    else
        return [rand(pricelist) for _ in 1:n]
    end 
end

struct Cargo
    type::String
    port::Int32
    arr::Float32
    rev::Float32
end

function genereate_cargo_structs(n;num_ports = 5, lambd = 1/60,seed = nothing)
    
    if seed !== nothing
        types = generate_cargo_type(n,rng=MersenneTwister(seed))
        ports = generate_cargo_port(n,num_ports=num_ports,rng=MersenneTwister(seed))
        arr_times = generate_arrival_times_exp(n,lambd = lambd,rng=MersenneTwister(seed))
        revs = generate_rev(n,rng=MersenneTwister(seed))
    else
        types = generate_cargo_type(n)
        ports = generate_cargo_port(n, num_ports=num_ports)
        arr_times = generate_arrival_times_exp(n,lambd=lambd)
        revs = generate_rev(n)
    end
    cargolist = [Cargo(types[i],ports[i],arr_times[i],revs[i]) for i in 1:n]

    return cargolist
end



