using HTTP
using URIs
using JSON

GEOCODE_SCHEME = "https"
GEOCODE_HOST = "maps.googleapis.com"
GEOCODE_PATH = "/maps/api/geocode/json"
GEOCODE_ADDRESS_KEY = "address"
GEOCODE_API_KEY = "key"
GEOCODE_ADDRESS_SUFFIX = "Victoria Australia"

"""
Construct a URI using the library and our constants
"""
generate_geocode_uri(address, suburb, api_key) =
    URI(scheme=GEOCODE_SCHEME, host=GEOCODE_HOST, path=GEOCODE_PATH, query=Dict([(GEOCODE_ADDRESS_KEY, string(address, " ", suburb, " ", GEOCODE_ADDRESS_SUFFIX)), (GEOCODE_API_KEY, api_key)]))

"""
Send a request through the URI
"""
get_geocode(address, suburb, api_key) = HTTP.get(generate_geocode_uri(address, suburb, api_key))

"""
Format the output
"""
function get_coordinates(address, suburb, api_key)
    location = get_geocode(address, suburb, api_key).body |> String |> JSON.parse |> x->x["results"][1]["geometry"]["location"]
    return location["lat"], location["lng"]
end