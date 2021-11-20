using CSV 
using DataFrames
using StatsPlots
using Statistics
using Dates

const FULL_FILE_PROCESSED = joinpath("data","Melbourne_housing_FULL_processed_2.csv")

const SOLD_METHODS = ["S", "SP", "PI", "PN", "SN", "SA", "SS"]

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

function aggregate_date_to_months!(df::AbstractDataFrame, col=:Date) 
    transform!(df, col => ByRow(x->DateTime(Dates.year(x), Dates.month(x))) => col)
end
"""
    plot_time_sales(df::AbstractDataFrame)

Returns a line graph of house sales over time, aggregated by month. Only considers houses with a Method in SOLD_METHODS.
"""
function plot_time_sales(df::AbstractDataFrame)
    df_time_sales = combine(groupby(filter!(:Method => x->x in SOLD_METHODS, select(df, :Date, :Method)) |> aggregate_date_to_months!, :Date), nrow => :count)

    xticks_range = DateTime(2015, 12):Dates.Month(4):DateTime(2017, 12)
    xticks=(xticks_range, [Dates.format(tick, "yyyy-mm") for tick in xticks_range])

    return @df df_time_sales plot(:Date, :count, seriestype=:line, xticks=xticks, xlims=(DateTime(2015, 10), DateTime(2018, 3)), linecolor=:red, linewidth=5, label=false, xlabel="Month of Sale", ylabel="Number of Properties Sold", plot_title="Properties Sold By Month")
end

"""
    plot_time_price(df::AbstractDataFrame)

Returns a line graph of mean sale price over time, aggregated by months. Two more lines appear on this chart; they are `mean + std` and `mean - std` respectively.
"""
function plot_time_price(df::AbstractDataFrame)
    df_time_price = combine(groupby(dropmissing!(filter!(:Method => x->x in SOLD_METHODS, select(df, :Date, :Method, :Price)) |> aggregate_date_to_months!, :Price), :Date), nrow => :count, :Price => mean => :Price_mean, :Price => std => :Price_std)

    transform!(df_time_price, [:Price_mean, :Price_std] => ByRow((x, y) -> (x - y, x + y)) => [:Price_mean_nstd, :Price_mean_pstd])

    plot_mean = @df df_time_price plot(:Date, :Price_mean, linewidth=5, seriestype=:line, linecolor=:green, label="Mean")

    yticks_range = 400000:400000:2000000
    yticks = (yticks_range, currency_format.(yticks_range))

    xticks_range = DateTime(2016, 4):Dates.Month(4):DateTime(2017, 12)
    xticks=(xticks_range, [Dates.format(tick, "yyyy-mm") for tick in xticks_range])

    return @df df_time_price plot(plot_mean, :Date, [:Price_mean_nstd, :Price_mean_pstd], linewidth=1, seriestype=:line, linestyle=:dash, linecolor=:blue, ylims=(0, 2000000), yticks=yticks, xticks=xticks, label="", xlabel="Month of Sale", ylabel="Mean Sale Price, w/ St. Dev. (\$AUD)", plot_title="Sale Price Over Time")
end

"""
    plot_time_type(df::AbstractDataFrame)

Returns a line graph of the proportion of houses sold in relation to other properties over time, aggregated by month.
"""
function plot_time_type(df::AbstractDataFrame)
    df_time_type = filter!(:Method => x->x in SOLD_METHODS, select(df, :Date, :Method, :Type) |> aggregate_date_to_months!)

    count_dates(df) = combine(groupby(df, :Date), :Type => x->count((a->a=="h"), x) / length(x))

    @show df_time_type_all = df_time_type |> count_dates

    xticks_range = DateTime(2016, 2):Dates.Month(4):DateTime(2018, 3)
    xticks=(xticks_range, [Dates.format(tick, "yyyy-mm") for tick in xticks_range])

    yticks_range = 0.5:0.05:0.8
    yticks = (yticks_range, 100 .* yticks_range)

    return @df df_time_type_all plot(:Date, :Type_function, seriestype=:line, linewidth=3, linecolor=:orange, label="", xticks=xticks, xlims = (DateTime(2016, 1), DateTime(2018, 3)), ylims=(0.45, 0.85), yticks=yticks, xlabel="Month of Sale", ylabel="Percentage of Properties Sold as Houses", plot_title = "Hice as a Proportion of Sold Properties", fillrange=0.45, fillcolor=:brown, tickdirection=:out)
end

generate_task3_df(filename=FULL_FILE_PROCESSED) = transform!(DataFrame(CSV.File(FULL_FILE_PROCESSED)), :Date => ByRow(x->Date(x, dateformat"d/m/y")) => :Date) |> sort!
