using CSV
using DataFrames
using Combinatorics

const FULL_FILE_PROCESSED = joinpath("data","Melbourne_housing_FULL_processed_2.csv")

df_full = DataFrame(CSV.File(FULL_FILE_PROCESSED))

df_pc = select(df_full, :Postcode, :CouncilArea, :Suburb, :Regionname) |> dropmissing!

"""
    counts_to_percent(nums::AbstractVector{Int})::Vector{Float32}

Helper function. Takes a `Vector` of numbers, divides each one by the sum of the `Vector`, and multiplies by 100.

# Examples
```jldoctest
julia>a=[1, 2, 3, 4]
[1, 2, 3, 4]
julia>counts_to_percent(a)
[10.0, 20.0, 30.0, 40.0]
```
"""
counts_to_percent(nums::AbstractVector{Int})::Vector{Float32} = nums .* 100 ./ sum(nums)

"""
    create_postcode_dict_for_cols(df_pc::AbstractDataFrame, cols)::Dict{Set{String}, Array{Tuple{Int, Float32}}}

Takes a dataframe with a `:Postcode` column and a list of other columns to group the postcode by, and returns a `Dict` with formatted data. This `Dict`'s keys are `Set`s of each combination of the grouping column's values; its vals are `Vector`select of `Tuples` that contain each postcode matching the key and its prevalence for the key as a percentage (in descending order).

For example, if for the key `{"Glensborough"}` there are 2 postcodes `3101` and 8 `3202`, the `Dict`'s corresponding val would contain `[(3202, 80.0), (3101, 20.0)]`
"""
function create_postcode_dict_for_cols(df_pc::AbstractDataFrame, cols)::Dict{Set{String}, Vector{Tuple{Int, Float32}}}

    # We must count each occurence, sort for convenience, and group for ease of transfer into the `Dict`
    df_pc_sub = groupby(sort!(combine(groupby(df_pc[!, [:Postcode, cols...]], [:Postcode, cols...]), nrow => :count), :count, rev=true), cols)

    dict_pc_sub = Dict{Set{String}, Vector{Tuple{Int, Float32}}}()

    # Iterate through our resulting DataFrame, and organise our return data struct as necessary
    for key in keys(df_pc_sub)
        dict_pc_sub[Set(key |> values)] = collect(zip(df_pc_sub[key][!, :Postcode], df_pc_sub[key][!, :count] |> counts_to_percent))
    end

    return dict_pc_sub 
end

"""
    create_postcode_dict_all(df_pc::AbstractDataFrame, cols)::Dict{Set, Dict{Set{String}, Vector{Tuple{Int, Float32}}}}

Takes a `DataFrame` and a `Vector` of its columns, and calls `create_postcode_dict_for_cols` for each combination of the given columns. The result is returned as a single dictionary.

Each key `col_comb` is a `Set` of columns, and its value the dictionary returned by `create_postcode_dict_for_cols(df_pc, col_comb)`.
"""
function create_postcode_dict_all(df_pc::AbstractDataFrame, cols)::Dict{Set, Dict{Set{String}, Vector{Tuple{Int, Float32}}}}
    final_dict = Dict{AbstractSet, AbstractDict}()
    for comb in combinations(cols)
        final_dict[Set(comb)] = create_postcode_dict_for_cols(df_pc, comb)
    end
    return final_dict
end

@debug "Testing single-value `Dict` creation." create_postcode_dict_for_cols(df_pc, [:Suburb])
@debug "Testing multi-value `Dict` creation." create_postcode_dict_for_cols(df_pc, [:CouncilArea, :Suburb])

beeg_dict = create_postcode_dict_all(df_pc, [:CouncilArea, :Suburb, :Regionname])

"""
    get_postcode(beeg_dict::AbstractDict{AbstractSet, AbstractDict{AbstractSet{String}, AbstractVector{Tuple{Int, Float32}}}};kwargs...)::Vector{Tuple{Int, Float32}}

Takes a `Dict` formatted as per `create_postcode_dict_all` and any number of columns to search (as well as the data to search for), and returns a `Vector` of `Tuples` of possible postcodes and the likelihood of their match.

To clarify the permitted `Dict` data structure:
```
                                                              Matching Postcode
                                                             ↗
Set(Col. Names) → Set(Search Data) → Vector of [ Tuples w/ ( ) ]
                                                             ↘
                                                              Match likelihood  
```

"""
function get_postcode(beeg_dict::AbstractDict{AbstractSet, AbstractDict{AbstractSet{String}, AbstractVector{Tuple{Int, Float32}}}};kwargs...)::Vector{Tuple{Int, Float32}}
    # Takes Vector of Tuples, returns a Vector of only the values in each tuple's tup_ind 
    slice_tuple(tup_vec, tup_ind) = Set(tup[tup_ind] for tup in tup_vec)
    return collect(beeg_dict[slice_tuple(kwargs, 1)][slice_tuple(kwargs, 2)])
end

"""
    generate_dict_from_file(filename=FULL_FILE_PROCESSED, cols=[:CouncilArea, :Suburb, :Regionname])

Takes the filename (`String``) of a CSV `DataFrame`, reads it, and runs it through `create_postcode_dict_all`. The returned dict is compatible with `get_postcode`.
"""
function generate_dict_from_file(filename=FULL_FILE_PROCESSED, cols=[:CouncilArea, :Suburb, :Regionname])
    return create_postcode_dict_all(select(DataFrame(CSV.File(filename)), :Postcode, cols...) |> dropmissing!, cols)
end

@debug "Testing arbitrary value for `get_postcode`." beeg_dict=generate_dict_from_file() && get_postcode(beeg_dict, Suburb="Rosanna", CouncilArea="Banyule City Council")
