using CSV
using DataFrames
using Combinatorics

const FULL_FILE_PROCESSED = joinpath("data","Melbourne_housing_FULL_processed_2.csv")

df_full = DataFrame(CSV.File(FULL_FILE_PROCESSED))

df_pc = select(df_full, :Postcode, :CouncilArea, :Suburb, :Regionname) |> dropmissing!

function create_postcode_dict_by_col(df_pc::AbstractDataFrame, cols)
    df_pc_sub = groupby(sort!(combine(groupby(df_pc[!, [:Postcode, cols...]], [:Postcode, cols...]), nrow => :count), :count, rev=true), cols)

    dict_pc_sub = Dict()

    counts_to_percent(nums) = nums .* 100 ./ sum(nums)

    for key in keys(df_pc_sub)
        dict_pc_sub[Set(key |> values)] = zip(df_pc_sub[key][!, :Postcode], df_pc_sub[key][!, :count] |> counts_to_percent)
    end

    return dict_pc_sub 
end

function postcode_intersect(pc_1, pc_2)
    pc_final = []
    for pc in pc_1
        pc[1] in [pc[1] for pc in pc_2] && push!(pc_final, pc)
    end

    #length(pc_final) > 0 && pc_final = sum([pc[2] for pc in pc_final])
    return pc_final
end

function create_postcode_dict_all(df_pc::AbstractDataFrame, cols)
    final_dict = Dict{AbstractSet, AbstractDict}()
    for comb in combinations(cols)
        final_dict[Set(comb)] = create_postcode_dict_by_col(df_pc, comb)
    end
    return final_dict
end

dic_1 = create_postcode_dict_by_col(df_pc, [:Suburb])
dic_2 = create_postcode_dict_by_col(df_pc, [:CouncilArea, :Suburb])

beeg_dict = create_postcode_dict_all(df_pc, [:CouncilArea, :Suburb, :Regionname])

"""
Pass in the beeg dict and a list of tuples. This list should be (:Column, data).
"""
function get_postcode(beeg_dict;kwargs...)
    return beeg_dict[Set(kwarg[1] for kwarg in kwargs)][Set(kwarg[2] for kwarg in kwargs)]
end

get_postcode(beeg_dict, Suburb="Rosanna", CouncilArea="Banyule City Council")
# println(dic_2)
# print(dic_1["Taylors Lakes"])
# println(keys(dic_2))