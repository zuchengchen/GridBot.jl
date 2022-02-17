using JSON
import HTTP, JSON
using DataFrames, DataStructures
import SHA, Printf, CSV
using ProgressMeter

include("../utils.jl")
include("../../time.jl")

const BINANCE_SPOT_BASE_URL = "https://api.binance.com/api/v3"
const BINANCE_FUTURE_BASE_URL = "https://fapi.binance.com/fapi/v1"

get_base_url(type="spot") = type=="spot" ? BINANCE_SPOT_BASE_URL : BINANCE_FUTURE_BASE_URL
string_to_float(string) = parse(Float64, string)

"""
USER stores the api_key and api_secret of an account.
"""
struct User
    key
    secret
    headers
    function User(api_key_file, user)
        api_dict = JSON.parsefile(api_key_file)[user]
        key = api_dict["key"]
        secret = api_dict["secret"]
        headers = Dict("X-MBX-APIKEY" => key)
        new(key, secret, headers)
    end
end

user = User("/home/bear/projects/working/stock/GridBot.jl/api_key.json", "binance_main_spot");

"""
Get account information.
"""
function get_account_info(user, type="spot")
    base_url = get_base_url(type)
    query = "recvWindow=5000&timestamp=$(timestamp_now())"
    signature = do_sign(query, user)
    body = "$base_url/account?$query&signature=$signature"
    response = HTTP.request("GET", body, user.headers)

    if response.status != 200
        println(response)
        return response.status
    end

    response_to_json(response.body)
end

a_info = get_account_info(user)

"""
Get balances.
"""
function get_balances_spot(user; balance_filter = x -> (string_to_float(x["free"]) + string_to_float(x["locked"])) > 0.0)
    account = get_account_info(user, "spot")
    balances = filter(balance_filter, account["balances"])
end

"""
Get balances.
"""
function get_balances_future(user; balance_filter = x -> string_to_float(x["walletBalance"]) > 0.0)
    account = get_account_info(user, "future")
    balances = filter(balance_filter, account["assets"])
end

get_balances_future(user)
get_balances_spot(user)

"""
Get open orders.
"""
function get_open_orders(user)
    query = "recvWindow=5000&timestamp=$(timestamp_now())"
    signature = do_sign(query, user)
    body = "https://api.binance.com/api/v3/openOrders?$query&signature=$signature"
    response = HTTP.request("GET", body, user.headers)
    response_to_json(response.body)
end
get_open_orders(user)