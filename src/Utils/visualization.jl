using CairoMakie,PlotlyJS,Plots,StatsPlots,Distributions
using Graphs, SimpleWeightedGraphs

function plot_deck(deck)
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
    hm = CairoMakie.heatmap!(ax, transpose(deck), colormap = colors, colorrange = (0, num_of_ports+2))

    legend_elements = [PolyElement(color = colors[i], strokecolor = :black) for i in 1:length(labels)]
    Legend(fig[1,2], legend_elements, names, "Category")

    fig
end

function plot_solution_details(sol_details)
    tags = ["revenue", "waiting costs", "shifting costs"]
    vals = sol_details
    PlotlyJS.plot(bar(x=tags, y=vals))
end

function plot_alns_sim(results;figtitle=nothing)
    if !isnothing(figtitle)
        Plots.plot(1:length(results),results,xlabel = "number of iterations",
    ylabel = "obj. val. of best solution",
    title=figtitle,legend = false)
    else
        Plots.plot(1:length(results),results,xlabel = "number of iterations",
    ylabel = "obj. val. of best solution",legend = false)
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
                arrowsize = 11,
                lengthscale = 0.8,
                color = :black,
                linewidth = 1
            )

        elseif weight == 1
            arrows!(
                ax,
                [x1], [y1],
                [dx], [dy],
                arrowsize = 11,
                lengthscale = 0.8,
                color = :blue,
                linewidth = 1
            )
        
        else
            arrows!(
                ax,
                [x1], [y1],
                [dx], [dy],
                arrowsize = 11,
                lengthscale = 0.8,
                color = :red,
                linewidth = 1
            )

            midx = (x1 + x2) / 2
            midy = (y1 + y2) / 2

            text!(
                ax,
                "$(round(weight, digits=2))",
                position = (midx, midy),
                fontsize = 6,
                color = :black,
                align = (:center, :center)
            )
        end
    end

    fig
end