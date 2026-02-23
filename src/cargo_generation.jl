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

function generate_arrival_times_exp(n;lambd=0.2, rng=nothing)
    if rng !== nothing
        return [rand(rng,Exponential(lambd)) for _ in 1:n]
    else
        return [rand(Exponential(lambd)) for _ in 1:n]
    end
end

function generate_rev(n;mu=1,sig=0.1,rng = nothing)
    if rng !== nothing
        return [rand(rng,Normal(mu,sig)) for _ in 1:n]
    else
        return [rand(Normal(mu,sig)) for _ in 1:n]
    end 
end

struct Cargo
    type::String
    port::Int32
    arr::Float32
    rev::Float32
end

function genereate_cargo_structs(n;seed = nothing)
    
    if seed !== nothing
        types = generate_cargo_type(n,rng=MersenneTwister(seed))
        ports = generate_cargo_port(n,rng=MersenneTwister(seed))
        arr_times = generate_arrival_times_exp(n,rng=MersenneTwister(seed))
        revs = generate_rev(n,rng=MersenneTwister(seed))
    else
        types = generate_cargo_type(n)
        ports = generate_cargo_port(n)
        arr_times = generate_arrival_times_exp(n)
        revs = generate_rev(n)
    end
    cargolist = [Cargo(types[i],ports[i],arr_times[i],revs[i]) for i in 1:n]

    return cargolist
end



