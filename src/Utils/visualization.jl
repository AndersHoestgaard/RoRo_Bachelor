using CairoMakie,PlotlyJS,Plots,StatsPlots,Distributions, Statistics
using Graphs, SimpleWeightedGraphs

function plot_deck(deck;horizontal = true)
    num_of_ports = maximum(deck)-2
    category_names = Dict(
    0 => "unavailable",
    1 => "Unoccupied",
    2 => "Ramp"
    )
    
    for i in 1:num_of_ports
        i
        category_names[i+2] = "For port $i"
    end


    labels = sort(collect(keys(category_names)))
    names = [category_names[label] for label in labels]

    color_dict = Dict(
        0 => :gray,      # unavailable
        1 => :white,     # Unoccupied
        2 => :green      # Ramp
    )

    port_colors = [:red, :yellow, :orange, :blue, :pink, :brown, :green1, :olive, :cyan]
    for i in 1:num_of_ports
        color_dict[i+2] = port_colors[i]
    end
    
    colors = [color_dict[label] for label in labels]

    
    rows,cols = size(deck)
    
    fig = Figure(size = (350, 500))

    
    ax = Axis(fig[1,1], aspect = DataAspect(),yreversed=true)
    if horizontal
        hm = CairoMakie.heatmap!(ax, deck, colormap = colors, colorrange = (0, num_of_ports+2))
    else
        hm = CairoMakie.heatmap!(ax, transpose(deck), colormap = colors, colorrange = (0, num_of_ports+2))
    end

    legend_elements = [PolyElement(color = colors[i], strokecolor = :black) for i in 1:length(labels)]
    Legend(fig[1,2], legend_elements, names, "Category")

    fig
end

function plot_solution_details(sol_details)
    tags = ["revenue", "waiting costs", "shifting costs"]
    vals = sol_details
    PlotlyJS.plot(bar(x=tags, y=vals))
end

function plot_alns_sim(results; figtitle=nothing, deck=nothing, deck_horizontal=true)
    # If no deck provided, behave as before and return a single plot
    if isnothing(deck)
        if !isnothing(figtitle)
            return Plots.plot(1:length(results), results,
                xlabel = "number of iterations",
                ylabel = "obj. val. of best solution",
                title = figtitle,
                legend = false)
        else
            return Plots.plot(1:length(results), results,
                xlabel = "number of iterations",
                ylabel = "obj. val. of best solution",
                legend = false)
        end
    end

    # When a deck matrix is provided, create a side-by-side layout: deck heatmap + alns plot
    # Build color mapping similar to `plot_deck`
    num_of_ports = maximum(deck) - 2
    color_dict = Dict(
        0 => :gray,
        1 => :white,
        2 => :green
    )
    port_colors = [:red, :yellow, :orange, :blue, :pink, :brown, :green1, :olive, :cyan]
    for i in 1:num_of_ports
        color_dict[i+2] = port_colors[i]
    end
    colors = [color_dict[i] for i in 0:maximum(deck)]

    # Prepare deck data orientation
    deck_data = deck
    if !deck_horizontal
        deck_data = transpose(deck)
    end

    # Deck heatmap using Plots (colormap built from discrete colors)
    p1 = Plots.heatmap(deck_data, colormap = cgrad(colors), colorbar = false,
        clims = (0, maximum(deck)), title = "Deck")

    # ALNS objective plot
    p2 = if !isnothing(figtitle)
            Plots.plot(1:length(results), results,
                xlabel = "number of iterations",
                ylabel = "obj. val. of best solution",
                title = figtitle,
                legend = false)
         else
            Plots.plot(1:length(results), results,
                xlabel = "number of iterations",
                ylabel = "obj. val. of best solution",
                legend = false)
         end

    Plots.plot(p1, p2, layout = (1, 2), size = (1000, 400))
end

function plot_param_tune(res::Dict; title=nothing, xlabel="parameter", ylabel="value", plot_line=true, marker=:circle)
    # Sort keys to ensure x is ordered
    ks = sort(collect(keys(res)))
    ys = [res[k] for k in ks]

    if plot_line
        Plots.plot(ks, ys, marker=marker, xlabel = xlabel, ylabel = ylabel, title = title, legend = false)
    else
        Plots.scatter(ks, ys, xlabel = xlabel, ylabel = ylabel, title = title, legend = false)
    end
end

function plot_exp_dist(lambdas)
    p = nothing
    for (i,lamb) in enumerate(lambdas)
        if i == 1
            p = StatsPlots.plot(Exponential(lamb), fill=(0, .5,:orange),label="λ = $lamb")
        else
            StatsPlots.plot!(p, Exponential(lamb), fill=(0, .5,:orange),label="λ = $lamb")
        end
    end
    return p
end

function plot_graph(deck, g::SimpleWeightedDiGraph)

    rows, cols = size(deck)

    fig = Figure(size = (800, 600))
    ax = Axis(fig[1,1], aspect = DataAspect(), yreversed = true,
              title = "Graph Representation of Deck")

    # Background deck
    num_of_ports = maximum(deck) - 2
    color_dict = Dict(
        0 => :gray,
        1 => :white,
        2 => :green
    )

    port_colors = [:red, :yellow, :orange, :blue, :pink, :brown,
                   :green1, :olive, :cyan]

    for i in 1:num_of_ports
        color_dict[i+2] = port_colors[i]
    end

    colors = [color_dict[i] for i in 0:maximum(deck)]

    CairoMakie.heatmap!(ax, transpose(deck),
             colormap = colors,
             colorrange = (0, maximum(deck)))

    # grid
    for x in 0.5:(cols+0.5)
    lines!(ax, [x, x], [0.5, rows + 0.5], color = :black, linewidth = 1)
    end

    for y in 0.5:(rows+0.5)
        lines!(ax, [0.5, cols + 0.5], [y, y], color = :black, linewidth = 1)
    end

    # Node positions
    m, n = rows, cols
    positions = Dict{Int, Tuple{Float64, Float64}}()

    for i in 1:m
        for j in 1:n
            node = (i-1)*n + j
            positions[node] = (j, i)
        end
    end

    # Plot edges
    for e in edges(g)

        src = e.src
        dst = e.dst
        weight = e.weight

        x1, y1 = positions[src]
        x2, y2 = positions[dst]

        dx = x2 - x1
        dy = y2 - y1

        
        if weight < 0.001
            arrows!(
                ax,
                [x1], [y1],
                [dx], [dy],
                arrowsize = 15,
                lengthscale = 0.4,
                color = :black,
                linewidth = 1
            )

        elseif weight == 1
            arrows!(
                ax,
                [x1], [y1],
                [dx], [dy],
                arrowsize = 15,
                lengthscale = 0.4,
                color = :blue,
                linewidth = 1
            )
        
        elseif weight == 2
            arrows!(
                ax,
                [x1], [y1],
                [dx], [dy],
                arrowsize = 15,
                lengthscale = 0.4,
                color = :pink,
                linewidth = 1
            )
        else
            arrows!(
                ax,
                [x1], [y1],
                [dx], [dy],
                arrowsize = 15,
                lengthscale = 0.4,
                color = :red,
                linewidth = 1
            )

            midx = (x1 + x2) / 2
            midy = (y1 + y2) / 2

            
        end
    end

    fig
end

function plot_alns_weights(alns_results)
    d,_,wd,wr,dn,rn = alns_results

    
    mean_r_w = mean(hcat(wr))
    mean_d_w = mean(hcat(wd))
    
    p1 = Plots.bar(string.(dn),mean_d_w, title="Destroy weights", xlabel="Destroy operators", ylabel="Mean weight", xrotation = 10)
    p2 = Plots.bar(string.(rn), mean_r_w, title="Repair weights", xlabel="Repair operators", ylabel="Mean weight", xrotation = 10)
    Plots.plot(p1, p2, layout=(2,1))
end

function plot_convergence(ob_vals_collection; step=100, ci_level=0.95, plottitle = "") # from chatgpt

    n_steps = length(ob_vals_collection)
    iterations = collect(step:step:step*n_steps)

    means = Float64[]
    lower = Float64[]
    upper = Float64[]

    z = 1.96  # ~95% CI (normal approx)

    for vals in ob_vals_collection
        μ = mean(vals)
        σ = std(vals)
        n = length(vals)

        ci = z * σ / sqrt(n)

        push!(means, μ)
        push!(lower, μ - ci)
        push!(upper, μ + ci)
    end

    fig = Figure(size=(800,600))
    ax = Axis(fig[1,1],
        xlabel = "Iterations",
        ylabel = "Objective Value",
        title = plottitle
    )

    # Confidence band (plot first so line appears on top)
    band!(ax, iterations, lower, upper, alpha=0.3, color=:blue)

    # Mean line
    lines!(ax, iterations, means, linewidth=2, color=:red)

    fig
end

function plot_alns_weights_his(results)
    best_deck, history, his_w_d, his_w_r, destroy_names, repair_names = results
    if length(his_w_d) == 0 && length(his_w_r) == 0
        error("No weight history provided")
    end

    plots = []

    if length(his_w_d) > 0
        mat_d = transpose(hcat(his_w_d...))
        nd = size(mat_d, 2)
        segs = 1:size(mat_d, 1)
        p1 = Plots.plot(segs, mat_d[:, 1], label = isempty(destroy_names) ? "d1" : destroy_names[1],lw=3)
        for j in 2:nd
            Plots.plot!(p1, segs, mat_d[:, j], label = isempty(destroy_names) ? "d$(j)" : destroy_names[j],lw=3)
        end
        push!(plots, p1)
    end

    if length(his_w_r) > 0
        mat_r = transpose(hcat(his_w_r...))
        nr = size(mat_r, 2)
        segs = 1:size(mat_r, 1)
        p2 = Plots.plot(segs, mat_r[:, 1], label = isempty(repair_names) ? "r1" : repair_names[1],lw=3)
        for j in 2:nr
            Plots.plot!(p2, segs, mat_r[:, j], label = isempty(repair_names) ? "r$(j)" : repair_names[j],lw=3)
        end
        push!(plots, p2)
    end

    if length(plots) == 2
        display(Plots.plot(plots[1], plots[2], layout = (2, 1), size = (900, 700)))
    else
        display(plots[1])
    end
end

function plot_four_decks(deck1, deck2, deck3, deck4; 
                        titles=["Deck 1", "Deck 2", "Deck 3", "Deck 4"],
                        horizontal=true)
    """
    Plot 4 decks in a 2x2 grid with a single shared legend.
    
    Arguments:
    - deck1, deck2, deck3, deck4: Deck matrices to plot
    - titles: Optional vector of titles for each deck [default: ["Deck 1", "Deck 2", "Deck 3", "Deck 4"]]
    - horizontal: Boolean for deck orientation [default: true]
    
    Returns:
    - Figure with 2x2 grid of deck plots and shared legend
    """
    
    # Find maximum value across all decks to determine color mapping
    max_val = maximum([maximum(deck1), maximum(deck2), maximum(deck3), maximum(deck4)])
    num_of_ports = max_val - 2
    
    # Build category mapping
    category_names = Dict(
        0 => "unavailable",
        1 => "Unoccupied",
        2 => "Ramp"
    )
    for i in 1:num_of_ports
        category_names[i+2] = "Port $i"
    end
    
    labels = sort(collect(keys(category_names)))
    names = [category_names[label] for label in labels]
    
    # Build color dictionary
    color_dict = Dict(
        0 => :gray,      # unavailable
        1 => :white,     # Unoccupied
        2 => :green      # Ramp
    )
    
    port_colors = [:red, :yellow, :orange, :blue, :pink, :brown, :green1, :olive, :cyan]
    for i in 1:num_of_ports
        color_dict[i+2] = port_colors[i]
    end
    
    colors = [color_dict[label] for label in labels]
    
    # Create figure with 2x2 grid
    fig = Figure(size = (1000, 900))
    
    # Plot each deck
    decks = [deck1, deck2, deck3, deck4]
    positions = [(1,1), (1,2), (2,1), (2,2)]
    
    for (idx, (deck, pos)) in enumerate(zip(decks, positions))
        ax = Axis(fig[pos...], aspect = DataAspect(), yreversed=true, title = titles[idx])
        
        if horizontal
            CairoMakie.heatmap!(ax, deck, colormap = colors, colorrange = (0, max_val))
        else
            CairoMakie.heatmap!(ax, transpose(deck), colormap = colors, colorrange = (0, max_val))
        end
        
        hidedecorations!(ax)
    end
    
    # Add shared legend
    legend_elements = [PolyElement(color = colors[i], strokecolor = :black) for i in 1:length(labels)]
    Legend(fig[1:2, 3], legend_elements, names, "Category", framevisible=true)
    
    fig
end