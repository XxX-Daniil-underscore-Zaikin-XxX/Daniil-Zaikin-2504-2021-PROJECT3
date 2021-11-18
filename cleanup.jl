using DataFrames
using CSV

include("coordinates.jl")

LESS_FILE = "MELBOURNE_HOUSE_PRICES_LESS.csv"
FULL_FILE = "Melbourne_housing_FULL.csv"
FULL_FILLED_FILE_PROCESSED = "Melbourne_housing_FULL_processed.csv"

API_KEY = "AIzaSyAnxxxFGwpJKRaGGAv0De9hNL0OqlHT6B0"

"""
    fix_coordinate_typos(df::AbstractDataFrame)::DataFrame

Returns a copy of a `DataFrame` with fixed typos in Latitude and Longitude columns
"""
fix_coordinate_typos(df::AbstractDataFrame)::DataFrame = rename(df, Dict(:Lattitude => "Latitude", :Longtitude => "Longitude"))

"""
    uppercasewordfirst(name::AbstractString)::String

Returns copy of a `String` where only the first letter of each word is capitalised.

# Examples
```jldoctest
julia>uppercasewordfirst("fOO BAr")
Foo Bar
```
"""
uppercasewordfirst(name::AbstractString)::String = join(uppercasefirst.(lowercase.(split(name, " "))), " ")

"""
    consolidate_string_case(df::AbstractDataFrame, cols=[:Suburb, :Address, :Regionname, :CouncilArea])::DataFrame

Returns a copy of the given `DataFrame`, where the data on each 
"""
consolidate_string_case(df::AbstractDataFrame, cols=[:Suburb, :Address, :Regionname, :CouncilArea])::DataFrame = transform(df, [col => ByRow(x -> uppercasewordfirst(x)) => col for col in cols]...)

df_init = DataFrame(CSV.File(LESS_FILE))

# df = transform(df_init, [:Suburb, :Address, :Regionname, :CouncilArea] => ByRow((a, b, c, d) -> uppercasewordfirst.(a, b, c, d)) => [:Suburb, :Address, :Regionname, :CouncilArea])

df = consolidate_string_case(df_init)

# show(df_init)
# show(df)
x = combine(groupby(df, [:Suburb]), nrow => :count)

# x[x.count .= 1, :]

y = filter(row -> row.count == 1, x)

@show(y)

x_1 = combine(groupby(df_init, [:Regionname]), nrow => :count)
y_1 = filter(row -> row.count == 1, x_1)

@show(y_1)

# z_cases = .!completecases(df)

# z = df[z_cases, :]

# @show(z)

find_missing_subset(dataframe, columns=:) = dataframe[.!completecases(dataframe, columns), :]



function list_missing_data(dataframe, columns=:)
    for col in propertynames(dataframe[!, columns])
        n_rows = nrow(find_missing_subset(dataframe, col))
        if n_rows > 0
            print(col, " has ", n_rows, " missing rows.\n")
        end
    end
end

print("\nPrinting LESS data:\n\n")
list_missing_data(df)



df_full = fix_coordinate_typos(transform(DataFrame(CSV.File(FULL_FILE)), :Suburb => x -> uppercasefirst.(x)))

# Price cannot be imputed, must be dropped for tasks

# Lati

print("\nPrinting FULL data:\n\n")
list_missing_data(df_full)

print("\nPrinting missing latitudes/longitudes:\n\n")
#print(find_missing_subset(df_full, [:Latitude, :Longitude]))



function get_block_of_missing_coords(df::DataFrame, to_edit::Bool, block_size=100)
    missing_df = df[.!completecases(df, [:Latitude, :Longitude]), :]
    return missing_df[vcat(max(nrow(missing_df) - block_size, 0) |> trues, min(block_size, nrow(missing_df)) |> falses) .⊻ to_edit, :]
end

# CSV.write(FULL_FILLED_FILE, df_full)

while true
    df_filled = DataFrame(CSV.File(FULL_FILLED_FILE_PROCESSED))

    missing_coords_yesedit = get_block_of_missing_coords(df_filled, true)
    missing_coords_noedit = get_block_of_missing_coords(df_filled, false)

    print("Editing ", nrow(missing_coords_yesedit), " rows.\n")
    print("Leaving behind ", nrow(missing_coords_noedit), " rows.\n")

    nrow(missing_coords_yesedit) == 0 && break

    transform!(missing_coords_yesedit, [:Suburb, :Address] => ByRow((subr, addr) -> get_coordinates(addr, subr, API_KEY)) => [:Latitude, :Longitude])

    # @show missing_coords

    len_filled = nrow(df_filled)

    filled_df = append!(append!(dropmissing(df_filled, [:Latitude, :Longitude]) |> allowmissing!,  missing_coords_yesedit), missing_coords_noedit)

    row_diff = len_filled - nrow(filled_df)

    print("Difference in rows: ", row_diff, ".\n")
    row_diff != 0 && break

    CSV.write(FULL_FILLED_FILE_PROCESSED, filled_df)
end