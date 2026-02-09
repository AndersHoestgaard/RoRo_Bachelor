using CairoMakie

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

    println(length(category_names))
    labels = sort(collect(keys(category_names)))
    names = [category_names[label] for label in labels]

    color_dict = Dict(
        0 => :gray,      # unavailable
        1 => :white,     # Unoccupied
        2 => :green      # Ramp
    )
    # Add colors for ports
    port_colors = [:red, :yellow, :orange, :blue, :pink, :brown, :green1, :olive, :cyan]
    for i in 1:num_of_ports
        color_dict[i+2] = port_colors[i]
    end
    
    colors = [color_dict[label] for label in labels]
    print(colors)
    fig = Figure(size = (600, 400))
    ax = Axis(fig[1,1], aspect = 1, yreversed = true)
    hm = CairoMakie.heatmap!(ax, deck, colormap = colors, colorrange = (0, num_of_ports+2))

    legend_elements = [PolyElement(color = colors[i], strokecolor = :black) for i in 1:length(labels)]
    Legend(fig[1,2], legend_elements, names, "Category")

    fig
end
