using CairoMakie
using PlotlyJS
using Plots

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
    if cols< rows 
        deck = transpose(deck)
    end
    fig = Figure(size = (350, 500))

    
    ax = Axis(fig[1,1], aspect = DataAspect(), yreversed = true)
    hm = CairoMakie.heatmap!(ax, deck, colormap = colors, colorrange = (0, num_of_ports+2))

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