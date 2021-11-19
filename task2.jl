using DataFrames
using CSV
using Statistics
using Random
using Plots.Measures
using Plots, StatsPlots

const FULL_FILE_PROCESSED = joinpath("data","Melbourne_housing_FULL_processed_2.csv")

df_full = DataFrame(CSV.File(FULL_FILE_PROCESSED))

currency_format(num)::String = "\$" * replace(num |> string, r"(?<=[0-9])(?=(?:[0-9]{3})+(?![0-9]))" => ",")

###
# Distance to CBD
###

function plot_distance_price(df_full::DataFrame)
    df_dp = transform!(dropmissing!(select(df_full, :Price, :Distance), [:Price, :Distance]), :Distance => ByRow(x->convert(Int, x ÷ 4 * 4)) => :Distance_grouped)

    # bit_rand = bitrand(nrow(df_dp))

    # df_dp = df_dp[(bit_rand .& bit_rand) .& bit_rand, :]

    

    y_ticks = 2500000:2500000:12500000

    @df df_dp boxplot(:Distance_grouped, :Price, xlabel= "Distance from CBD (km)", ylabel = "Sale Price (\$AUD)", yticks=(y_ticks, currency_format.(y_ticks)), outliers=false, range=5, width=1, label="", plot_title="Price vs. Distance From CBD")

    #show(df_dp, allrows=false)
end

###
# Price vs. Rooms
###

function plot_rooms_price(df_full::DataFrame)
    df_rp_init = sort!(transform!(select(df_full, :Price, :Rooms) |> dropmissing!, :Price => ByRow(x->x÷500000*500000+1) => :Price_adj), :Price_adj)

    # df_rp = combine(groupby(df_rp_init, :Rooms), :Price => mean => :Price)

    yticks=10 .^ collect(5:7)

    @df df_rp_init plot(:Rooms, :Price, seriestype=:box, outliers=false, range=5, label="", xlabel = "Rooms in Property", ylabel = "Price (\$AUD)", xticks=2:2:20, yscale=:log10, yticks=(yticks, currency_format.(yticks)), ylims=(10^4.9, 10^7), plot_title="Rooms vs. Price")    
end

###
# Price vs. Rooms and CBD Distance
###

function plot_rooms_distance_price(df_full::DataFrame)
    df_rdp = combine(groupby(select(df_full, :Rooms, :Distance => ByRow(floor) => :Distance, :Price) |> dropmissing!, [:Rooms, :Distance]), :Price => mean => :Price_mean)
    #print(df_rdp[23181, :])
    zticks=10 .^ collect(5:7)
    @df df_rdp plot(:Distance, :Rooms, :Price_mean, seriestype=:surface, zscale=:log10, camera = (50,70), zlims=(5000, 10000000), size=(800, 500), xlims=(0, 50), ylims=(0, 16), yflip=true, xflip=true, xlabel="Distance from CBD (km)                         ", ylabel="          Number of Rooms", zlabel="Average Sale Price (\$AUD)", plot_title="Room and CBD Distance as a Factor in Price", left_margin=5mm, right_margin=5mm, zticks=(zticks, currency_format.(zticks)))
end

#plot_rooms_price(df_full)
#plot_distance_price(df_full)
plot_rooms_distance_price(df_full)