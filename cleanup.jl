using DataFrames
using CSV

include("coordinates.jl")

# All relevant filenames
const LESS_FILE = joinpath("data","MELBOURNE_HOUSE_PRICES_LESS.csv")
const LESS_FILE_PROCESSED = joinpath("data", "MELBOURNE_HOUSE_PRICES_LESS_PROCESSED.csv")
const FULL_FILE = joinpath("data", "Melbourne_housing_FULL_processed.csv")
const FULL_FILE_PROCESSED = joinpath("data","Melbourne_housing_FULL_processed_2.csv")

# Set to true if current processed files need to be overwritten
const OVERWRITE_PROCESSED = false

# Set to true if we must overwrite the coordinates
const OVERWRITE_COORDINATES = false

# Gonna put this in a .env later - if this was a real repo, I'd do it earlier
const API_KEY = "AIzaSyAnxxxFGwpJKRaGGAv0De9hNL0OqlHT6B0"

"""
    fix_coordinate_typos(df::AbstractDataFrame)::DataFrame

Returns a copy of a `DataFrame` with fixed typos in Latitude and Longitude columns
"""
fix_coordinate_typos(df::AbstractDataFrame)::DataFrame = if ("Lattitude" in names(df) && "Longtitude" in names(df)) rename(df, Dict(:Lattitude => "Latitude", :Longtitude => "Longitude")) else df end

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

Returns a copy of the given `DataFrame`, where the (`String``) data in each of the given columns is changed as per the `uppercasewordfirst` function.
"""
consolidate_string_case(df::AbstractDataFrame, cols=[:Suburb, :Address, :Regionname, :CouncilArea])::DataFrame = transform(df, [col => ByRow(x -> uppercasewordfirst(x)) => col for col in cols]...)

replace_missing_data(df::AbstractDataFrame, cols=[:Distance]) = transform(df, [col => ByRow(x -> if (x == "#N/A") missing else parse(Float16, x) end) => col for col in cols]...)

df_less = DataFrame(CSV.File(LESS_FILE)) |> consolidate_string_case

df_full = DataFrame(CSV.File(FULL_FILE)) |> consolidate_string_case |> fix_coordinate_typos

x = combine(groupby(df_less, [:Suburb]), nrow => :count)

y = filter(row -> row.count == 1, x)

@debug y

x_1 = combine(groupby(df_less, [:Regionname]), nrow => :count)
y_1 = filter(row -> row.count == 1, x_1)

@debug y_1

"""
    find_missing_subset(dataframe::AbstractDataFrame, columns=:)::DataFrame

Returns a copy of the given `DataFrame` that has `missing` records in any of the passed columns (all columns by default)
"""
find_missing_subset(dataframe::AbstractDataFrame, columns=:)::DataFrame = dataframe[.!completecases(dataframe, columns), :]

"""
    list_missing_data(dataframe::AbstractDataFrame, columns=:)

If `JULIA_DEBUG`, prints some information about missing data in the given columns. Otherwise, it does nothing.
"""
function list_missing_data(dataframe::AbstractDataFrame, columns=:)
    info = []
    for col in propertynames(dataframe[!, columns])
        n_rows = nrow(find_missing_subset(dataframe, col))
        if n_rows > 0
            push!(info, "$(col) has $(n_rows) missing rows.")
        end
    end
    return info
end

@info "Missing LESS data: \n\t$(join(list_missing_data(df_less), "\n\t"))"

@info "Missing FULL data: \n\t$(join(list_missing_data(df_full), "\n\t"))"

@debug "Missing latitudes/longitudes:" find_missing_subset(df_full, [:Latitude, :Longitude])


"""
    get_block_of_missing_coords(df::AbstractDataFrame, to_edit::Bool, block_size=100)::DataFrame

Specialised function. Returns a `DataFrame` that contains the last `block_size` rows of `df` that are missing their `Latitude` and `Longitude` if `to_edit` is `true`; otherwise, returns a `DataFrame` that contains all records with missing coordinates save for the last `block_size` rows.
"""
function get_block_of_missing_coords(df::AbstractDataFrame, to_edit::Bool, block_size=100)::DataFrame
    missing_df = df[.!completecases(df, [:Latitude, :Longitude]), :]
    return missing_df[vcat(max(nrow(missing_df) - block_size, 0) |> trues, min(block_size, nrow(missing_df)) |> falses) .⊻ to_edit, :]
end

# Handle file renaming, creating

OVERWRITE_PROCESSED && @warn "Overwriting existing files"

no_file_message(type::String) = "Could not find $(type) file. Creating new."

!isfile(FULL_FILE_PROCESSED) && @warn no_file_message("FULL")
(OVERWRITE_PROCESSED || !isfile(FULL_FILE_PROCESSED)) && CSV.write(FULL_FILE_PROCESSED, df_full)

!isfile(LESS_FILE_PROCESSED) && @warn no_file_message("LESS")
(OVERWRITE_PROCESSED || !isfile(LESS_FILE_PROCESSED)) && CSV.write(LESS_FILE_PROCESSED, df_less)

# Loop through our missing coordinates and fill them in chunk-by-chunk. Writes to the file and reads from it once each loop.
while OVERWRITE_COORDINATES
    # Read a fresh DataFrame from the file (slow, but saves on API calls in case of error)
    df_filled = DataFrame(CSV.File(FULL_FILE_PROCESSED))

    # Populate the missing set we won't touch, and the one we will
    missing_coords_yesedit = get_block_of_missing_coords(df_filled, true)
    missing_coords_noedit = get_block_of_missing_coords(df_filled, false)

    if nrow(missing_coords_yesedit) == 0 
        @info "No more coordinates to fill."
        break
    end

    @info "Editing $(nrow(missing_coords_yesedit)) rows."
    @info "Leaving behind $(nrow(missing_coords_noedit)) rows."

    # Populate the missing coordinates
    transform!(missing_coords_yesedit, [:Suburb, :Address] => ByRow((subr, addr) -> get_coordinates(addr, subr, API_KEY)) => [:Latitude, :Longitude])

    len_filled = nrow(df_filled)

    # Re-arrange and fill our file-read DataFrame with our new data
    filled_df = append!(append!(dropmissing(df_filled, [:Latitude, :Longitude]) |> allowmissing!,  missing_coords_yesedit), missing_coords_noedit)

    row_diff = len_filled - nrow(filled_df)

    @info "Difference in rows: $(row_diff)"
    if row_diff != 0
        # Likely that something's gone wrong, will need a human eye
        @error "Output `DataFrame` differs from input `DataFrame`. Exiting."
        break
    end

    # Overwrite the file
    CSV.write(FULL_FILE_PROCESSED, filled_df)
end