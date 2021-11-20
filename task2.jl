using DataFrames
using CSV
using Statistics
using Random
using Plots.Measures
using Plots, StatsPlots

const FULL_FILE_PROCESSED = joinpath("data","Melbourne_housing_FULL_processed_2.csv")



"""
    currency_format(num)::String

Takes a number, returns it as a string in currency (\$AUD) form. Taken from [here](https://stackoverflow.com/questions/52213829/in-julia-insert-commas-into-integers-for-printing-like-python-3-6/52213830#52213830).

# Examples
```jldoctest
julia>a = 10000
10000
julia>currency_format(a)
\$10,000
```
"""
currency_format(num)::String = "\$" * replace(num |> string, r"(?<=[0-9])(?=(?:[0-9]{3})+(?![0-9]))" => ",")

###
# Distance to CBD
###

"""
    plot_distance_price(df_full::AbstractDataFrame)

Plots price in relation to distance as a box-and-whisker plot (range=5), the latter grouped in 4km segments.

X = distance from CBD (km), Y = sale price for properties within the distance group.
"""
function plot_distance_price(df_full::DataFrame)
    df_dp = transform!(dropmissing!(select(df_full, :Price, :Distance), [:Price, :Distance]), :Distance => ByRow(x->convert(Int, x ÷ 4 * 4)) => :Distance_grouped)

    y_ticks = 2500000:2500000:12500000

    return @df df_dp boxplot(:Distance_grouped, :Price, xlabel= "Distance from CBD (km)", ylabel = "Sale Price (\$AUD)", yticks=(y_ticks, currency_format.(y_ticks)), outliers=false, range=5, width=1, label="", plot_title="Price vs. Distance From CBD")
end

###
# Price vs. Rooms
###

"""
    plot_rooms_price(df_full::AbstractDataFrame)

Plots sale price against number of rooms as a box-and-whisker plot (range=5).

X = number of rooms, Y = sale price for properties with that number of rooms. Y scale is log10.
"""
function plot_rooms_price(df_full::DataFrame)
    df_rp_init = sort!(transform!(select(df_full, :Price, :Rooms) |> dropmissing!, :Price => ByRow(x->x÷500000*500000+1) => :Price_adj), :Price_adj)

    yticks=10 .^ collect(5:7)

    return @df df_rp_init plot(:Rooms, :Price, seriestype=:box, outliers=false, range=5, label="", xlabel = "Rooms in Property", ylabel = "Price (\$AUD)", xticks=2:2:20, yscale=:log10, yticks=(yticks, currency_format.(yticks)), ylims=(10^4.9, 10^7), plot_title="Rooms vs. Price")    
end

###
# Price vs. Rooms and CBD Distance
###

"""
    plot_rooms_distance_price(df_full::AbstractDataFrame)

Plots sale price against number of rooms and distance from CBD as three-dimensional surface plot.

X = distance from CBD (km), Y = num. of rooms, Z = mean sale price for props. w/ that num. of rooms and distance. Z scale is log10.

Note that Z tick labels are incorrectly placed. Their true position should correspond to the grid.
"""
function plot_rooms_distance_price(df_full::DataFrame)
    df_rdp = combine(groupby(select(df_full, :Rooms, :Distance => ByRow(floor) => :Distance, :Price) |> dropmissing!, [:Rooms, :Distance]), :Price => mean => :Price_mean)
    zticks=10 .^ collect(5:7)
    return @df df_rdp plot(:Distance, :Rooms, :Price_mean, seriestype=:surface, zscale=:log10, camera = (50,70), zlims=(5000, 10000000), size=(800, 500), xlims=(0, 50), ylims=(0, 16), yflip=true, xflip=true, xlabel="Distance from CBD (km)                         ", ylabel="          Number of Rooms", zlabel="Average Sale Price (\$AUD)", plot_title="Room and CBD Distance as a Factor in Price", left_margin=5mm, right_margin=5mm, zticks=(zticks, currency_format.(zticks)))
end

"""
    generate_task2_df(filename=FULL_FILE_PROCESSED)

Generates a `DataFrame` from a CSV file for use throughout this task.
"""
generate_task2_df(filename=FULL_FILE_PROCESSED) = DataFrame(CSV.File(filename))