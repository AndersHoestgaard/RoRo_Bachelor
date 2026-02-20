using Random, Distributions

function generate_cargo_type(n)
    
    return rand(["car" "truck" "machinery" "container"],n)
end

function generate_cargo_port(n, num_ports=5)
    
    return rand([i for i in 3:num_ports+2],n)
end 

function generate_arrival_times_exp(n,lambd=0.2)
    return [rand(Exponential(lambd)) for _ in 1:n]
end

function generate_rev(n,mu=1,sig=0.1)
    return [rand(Normal(mu,sig)) for _ in 1:n]
end

struct Cargo
    type::String
    port::Int32
    arr::Float32
    rev::Float32
end

function genereate_cargo_structs(n,seed = nothing)
    
    types = generate_cargo_type(n)
    ports = generate_cargo_port(n)
    arr_times = generate_arrival_times_exp(n)
    revs = generate_rev(n)

    cargolist = [Cargo(types[i],ports[i],arr_times[i],revs[i]) for i in 1:n]

    return cargolist
end



