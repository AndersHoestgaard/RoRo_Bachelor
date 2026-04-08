#include(joinpath(pwd(),))
include("run_alns.jl")



function convergence_analysis(deck,cargo;runs_per_it=20,max_iterations=10000,stepsize=100)
    
    its = step

    ob_vals_collection = [[] for st in 1:Int(max_iterations/stepsize)]

    for i in 1:runs_per_it
        d,c,h = alns_hansen_basket(deck,cargo,iterations=max_iterations)
        
        for s in 1:Int(max_iterations/stepsize)
            push!(ob_vals_collection[s],h[s*stepsize])
        end
    end
    return ob_vals_collection
end


