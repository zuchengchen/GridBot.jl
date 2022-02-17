"""
USER stores the api_key and api_secret of an account.
"""
struct User
    key
    secret
    headers
    function User(api_key_file)
        api_dict = JSON.parsefile(api_key_file)
        key = api_dict["key"]
        secret = api_dict["secret"]
        headers = Dict("X-MBX-APIKEY" => key)
        new(key, secret, headers)
    end
end


"""
Get account information.
"""
function get_account_info(user)
    query = "recvWindow=5000&timestamp=$(timestamp_now())"
    signature = do_sign(query, user)
    body = "$BINANCE_FUTURE_BASE_URL/fapi/v1/account?$query&signature=$signature"
    response = HTTP.request("GET", body, user.headers)

    if response.status != 200
        println(response)
        return response.status
    end

    response_to_json(response.body)
end


"""
Get balances.
"""
function get_balances(user; balance_filter = x -> parse(Float64, x["walletBalance"]) > 0.0)
    account = get_account_info(user)
    balances = filter(balance_filter, account["assets"])
end


"""
Get open orders.
"""
function get_open_orders(user)
    query = "recvWindow=5000&timestamp=$(timestamp_now())"
    signature = do_sign(query, user)
    body = "$BINANCE_FUTURE_BASE_URL/fapi/v1/openOrders?$query&signature=$signature"
    response = HTTP.request("GET", body, user.headers)
    response_to_json(response.body)
end
