using DataFrames
using Plots
using CSV
using StatsPlots

const FULL_FILE_PROCESSED = joinpath("data","Melbourne_housing_FULL_processed_2.csv")

# Initialise our dataframe
df_full = DataFrame(CSV.File(FULL_FILE_PROCESSED))

"""
    prepare_cumplot(df_full::AbstractDataFrame, column)

Returns a dataframe with two columns, `column` and `cum_rownum`. All `missing` values (in `column` only) are dropped, and the existing values are sorted. `cum_rownum` holds each row's index in reverse - a single variable cumulative sum.
"""
function prepare_cumplot(df_full::AbstractDataFrame, column)
    df_cum = select(df_full, column) |> dropmissing! |> sort!
    df_cum[!, :cum_rownum] = nrow(df_cum):-1:1
    return df_cum
end

###
# Rooms
###

# No missing data, so we can proceed as always

"""
    plot_rooms(df_full::AbstractDataFrame)

Returns Room distribution as a bar graph.

X = num. of rooms, Y = num. of properties that contain that many rooms; Y is in log10 scale.
"""
function plot_rooms(df_full::AbstractDataFrame)
    df_rooms = combine(groupby(df_full, :Rooms), nrow => :count)

    # Discrete data? Bar graph.
    return @df df_rooms plot(:Rooms, :count, seriestype = :bar, xlabel = "Rooms", ylabel = "Property Count", label = "", yscale=:log10, xticks=1:20, plot_title = "Room Distribution")
end

###
# Price
###

# We are operating on a single variable, so we can simply discard missing values
"""
    plot_price(df_full::AbstractDataFrame)

Plots distribution of price as a cumulative sum line.

X = price (\$AUD), Y = number of propetries that have sold for more than that price; Y is in log10 scale.
"""
function plot_price(df_full::AbstractDataFrame)
    # df_price = select(df_full, :Price) |> dropmissing! |> sort!
    # df_price[!, :cum_rownum] = 1:-1:nrow(df_price)
    df_price = prepare_cumplot(df_full, :Price)
    transform!(df_price, :Price => cumsum => :Price_cum)

    # We will use a cumulative plot. It feels appropriate, considering we are using continuous data of a large volume.
    return @df df_price plot(:Price, :cum_rownum, xscale=:log10, xticks = ([100000, 1000000, 10000000], ["\$10,000", "\$100,000", "\$1,000,000"]), yformatter = :plain, label="", xlabel = "Property Sale Price (\$AUD)", ylabel = "Num. of Properties Sold For More", plot_title = "Cumulative Sale Price")#, yticks = 1:10^8:5*10^8)
end

###
# Distance
###

# One special case 'bad value', handled by our cleanup
"""
    plot_distance(df_full::AbstractDataFrame)

Plots distribution of price as a distance sum line.

X = distance (km), Y = number of propetries that are further from the CBD than that distance; Y is in linear scale.
"""
function plot_distance(df_full::AbstractDataFrame)
    df_distance = prepare_cumplot(transform(df_full |> dropmissing, :Distance => ByRow(x->x isa String ? parse(Float16, x) : x) => :Distance), :Distance)

    # We will use a cumulative plot. It feels appropriate, considering we are using continuous data of a large volume.
    return @df df_distance plot(:Distance, :cum_rownum, xticks=0:10:50, yformatter = :plain, label="", xlabel="Distance From CBD (km)", ylabel="Num. of Properties Further From CBD", plot_title="Cumulative CBD Distance")
end

"""
    plot_method(df_full::AbstractDataFrame)

Plots distribution of sale method as a bar chart.

X = sale method (abbreviated), Y = num. of prop. that have been sold via that method; Y is in linear scale.
"""
function plot_method(df_full::AbstractDataFrame)
    df_method = sort!(combine(groupby(df_full, :Method), nrow => :count), :count)

    # Discrete data? Bar graph.
    return @df df_method plot(:Method, :count, seriestype = :bar, xlabel = "Sale Method", ylabel = "Property Count", label = "", yformatter = :plain, plot_title = "Sale Method")
end

"""
    plot_landsize(df_full::AbstractDataFrame)

Plots distribution of land size method as a line graph. Landsizes have been grouped

X = landsize (m²), Y = num. of prop. sold with that landsize; X is in log10 scale.
"""
function plot_landsize(df_full::AbstractDataFrame)
    # Manipulating the data here for convenience
    df_landsize = combine(groupby(transform!(filter!(:Landsize => x->x>5, select(df_full, :Landsize) |> dropmissing! |> sort!), :Landsize => ByRow(x -> convert(Int, x - 5 |> float |> x->(10*log10(x)) |> floor)) => :Landsize_Grouped), :Landsize_Grouped), nrow => :count)

    # Function to convert axes from log10 to what they should be
    adjustment_func(num::Int) = convert(Int, 10^(num / 10.0) |> floor)

    # X-Axis won't be 100% accurate, be difference would be too minute to matter
    return @df df_landsize plot(:Landsize_Grouped, :count, seriestype = :line, xticks=(10:10:56, adjustment_func.(10:10:56)), label="", tickfonthalign=:center, xlabel="Landsize (m²)", ylabel="Number of Properties", plot_title="Property Landsizes")
end

"""
    generate_task1_df(filename=FULL_FILE_PROCESSED)

Generates a `DataFrame` from a CSV file for use throughout this task.
"""
generate_task1_df(filename=FULL_FILE_PROCESSED) = DataFrame(CSV.File(filename))

"""
    save_plots(tasknum::Int, df_creator::Function;plot_funcs::Vector{Function}, filename=FULL_FILE_PROCESSED)

Given a task number, a `DataFrame` generator `Function` that takes a file name as a parameter, and a `Vector` of `Functions` which take this `DataFrame` and output `Plot`s, this function saves all such `Plot`s as appropriately named .png files in the output directory.
"""
function save_plots(tasknum::Int, df_creator::Function;plot_funcs::Vector{Function}, filename=FULL_FILE_PROCESSED)
    df = df_creator(filename)
    for (i, func) in enumerate(plot_funcs)
        savefig(func(df), "output/task$(tasknum).$(i).png")
    end
end;