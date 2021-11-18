using HTTP
using URIs
using JSON

# Some basic constants to do URI
const GEOCODE_SCHEME = "https"
const GEOCODE_HOST = "maps.googleapis.com"
const GEOCODE_PATH = "/maps/api/geocode/json"
const GEOCODE_ADDRESS_KEY = "address"
const GEOCODE_API_KEY = "key"
const GEOCODE_ADDRESS_SUFFIX = "Victoria Australia"

"""
    generate_geocode_uri(address::String, suburb::String, api_key::String)::URI

Construct `URI` based on our constants and given variables
"""
generate_geocode_uri(address::String, suburb::String, api_key::String)::URI =
    URI(scheme=GEOCODE_SCHEME, host=GEOCODE_HOST, path=GEOCODE_PATH, query=Dict([(GEOCODE_ADDRESS_KEY, string(address, " ", suburb, " ", GEOCODE_ADDRESS_SUFFIX)), (GEOCODE_API_KEY, api_key)]))

"""
    get_geocode(address, suburb, api_key)

Send a GET request to Google's Geocoding API based on the given vars and our constants
"""
get_geocode(address, suburb, api_key) = HTTP.get(generate_geocode_uri(address, suburb, api_key))

"""
    get_coordinates(address::String, suburb::String, api_key::String)::Tuple{Float64, Float64}

Takes a street address and a suburb, and returns a `Tuple` (Latitude, Longitude) of that house's coordinates - as per Google's Geocoding API. It assumes the house is in Victoria, Australia.

# Examples
```jldoctest
julia>get_coordinates("85 studley st", "abbotsford", "ImaginaryAPIKey")
(-37.8015848, 144.99679)
```
"""
function get_coordinates(address::String, suburb::String, api_key::String)::Tuple{Float64, Float64}
    location = get_geocode(address, suburb, api_key).body |> String |> JSON.parse |> x->x["results"][1]["geometry"]["location"]
    return location["lat"], location["lng"]
end