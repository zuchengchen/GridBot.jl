import Dates, SHA, HTTP, JSON, Printf

const BINANCE_FUTURE_BASE_URL = "https://fapi.binance.com"
const BINANCE_FUTURE_ORDER_URL = "$BINANCE_FUTURE_BASE_URL/fapi/v1/order"
const BINANCE_FUTURE_KLINES_URL = "$BINANCE_FUTURE_BASE_URL/fapi/v1/klines"
const BINANCE_FUTURE_WS = "wss://fstream.binance.com/ws"


"""
Ping to the url.
"""
function ping(url)
    r = HTTP.request("GET", url)
    r.status
end

"""
Simple test if Binance future api is online or not.
"""
function ping_future()
    url = "$BINANCE_FUTURE_BASE_URL/fapi/v1/ping"
    ping(url)
end

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
Convert a datetime to timestamp in the units of milliseconds.
"""
function datetime_to_timestamp(datetime::Dates.DateTime)
    Printf.@sprintf("%.0d", Dates.datetime2unix(datetime) * 1000)
end

"""
Convert a timestamp in the units of milliseconds to datetime format.
"""
function timestamp_to_datetime(ts)
    Dates.unix2datetime(ts/1000)
end


"""
Return the timestamp of now in the units of milliseconds.
"""
function timestamp_now()
    datetime = Dates.now(Dates.UTC)
    datetime_to_timestamp(datetime)
end


"""
Convert a datetime sting to timestamp.
datetime should in the format of "2021-03-01" or "2021-03-01T03:01:24"
"""
function datetime_to_timestamp(datetime::String)
    dt = Dates.DateTime(datetime)
    datetime_to_timestamp(dt)
end


"""
Create an order dict to be executed later.
"""
function create_order_dict(symbol::String, order_side::String; 
        quantity::Float64=0.0, order_type::String = "LIMIT", 
        price::Float64=0.0, stop_price::Float64=0.0, 
        iceberg_qty::Float64=0.0, new_client_order_id::String="")
    
    if quantity <= 0.0
        error("Quantity cannot be <=0 for order type.")
    end
    
    println("$order_side => $symbol qty: $quantity, price: $price ")
    
    order = Dict(
        "symbol"           => symbol, 
        "side"             => order_side,
        "type"             => order_type,
        "quantity"         => Printf.@sprintf("%.8f", quantity),
        "newOrderRespType" => "FULL",
        "recvWindow"       => 10000
    )
    
    if new_client_order_id != ""
        order["newClientOrderId"] = new_client_order_id;
    end
    
    if order_type == "LIMIT" || order_type == "LIMIT_MAKER"
        if price <= 0.0
            error("Price cannot be <= 0 for order type.")
        end
        
        if price * quantity < 5.0
            error("Order's notional must be no smaller than 5.0 (unless you choose reduce only)")
        end
        
        order["price"] =  Printf.@sprintf("%.8f", price)
    end
    
    if order_type == "STOP_LOSS" || order_type == "TAKE_PROFIT"
        if stop_price <= 0.0
            error("Stop price cannot be <= 0 for order type.")
        end
        order["stopPrice"] = Printf.@sprintf("%.8f", stop_price)
    end
    
    if order_type == "STOP_LOSS_LIMIT" || order_type == "TAKE_PROFIT_LIMIT"
        if price <= 0.0 || stop_price <= 0.0
            error("Price or stop price cannot be <= 0 for order type.")
        end
        order["price"] =  Printf.@sprintf("%.8f", price)
        order["stopPrice"] =  Printf.@sprintf("%.8f", stop_price)
    end
    
    if order_type == "TAKE_PROFIT"
        if price <= 0.0 || stop_price <= 0.0
            error("Price or stop price cannot be <= 0 for STOP_LOSS_LIMIT order type.")
        end
        order["price"] =  Printf.@sprintf("%.8f", price)
        order["stopPrice"] =  Printf.@sprintf("%.8f", stop_price)
    end 
    
    if order_type == "LIMIT"  || order_type == "STOP_LOSS_LIMIT" || order_type == "TAKE_PROFIT_LIMIT"
        order["timeInForce"] = "GTC"
    end
    
    order
end


"""
Convert an order_dict to an string parameter.
"""
function order_dict_to_params(order_dict::Dict)
    params = ""
    for (key, value) in order_dict
        params = "$params&$key=$value"
    end
    params[2:end]
end


"""
Hash the msg with key.
"""
function hmac(key::Vector{UInt8}, msg::Vector{UInt8}, hash, blocksize::Int=64)
    if length(key) > blocksize
        key = hash(key)
    end

    pad = blocksize - length(key)

    if pad > 0
        resize!(key, blocksize)
        key[end - pad + 1:end] = 0
    end

    o_key_pad = key .⊻ 0x5c
    i_key_pad = key .⊻ 0x36

    hash([o_key_pad; hash([i_key_pad; msg])])
end


"""
Sigh the query message with api_secret.x
"""
function do_sign(query, user)
    hash_value = hmac(Vector{UInt8}(user.secret), Vector{UInt8}(query), SHA.sha256)
    bytes2hex(hash_value)
end


"""
Convert HTTP response to JSON
"""
function response_to_json(response)
    JSON.parse(String(response))
end


"""
Execute an order to the account.
"""
function execute_order(order::Dict, user::User; execute=true)
    order_params = order_dict_to_params(order)
    query = "$order_params&timestamp=$(timestamp_now())"
    signature = do_sign(query, user)
    body = "$BINANCE_FUTURE_ORDER_URL?$query&signature=$signature"   
    response = HTTP.request("POST", body, user.headers)
    response_to_json(response.body)
end


"""
Cancel an order from user.
"""
function cancel_order(order, user)
    query = "recvWindow=5000&timestamp=$(timestamp_now())&symbol=$(order["symbol"])&origClientOrderId=$(order["clientOrderId"])"
    signature = do_sign(query, user)
    body = "$BINANCE_FUTURE_ORDER_URL?$query&signature=$signature"
    response = HTTP.request("DELETE", body, user.headers)
    response_to_json(response.body)
end

"""
Get Binance server time.
""" 
function get_server_time()
    url = "$BINANCE_FUTURE_BASE_URL/fapi/v1/time"
    result = request_get(url)
    Dates.unix2datetime(result["serverTime"] / 1000)
end

"""
Get the request and convert to json.
"""
function request_get(url)
    r = HTTP.request("GET", url)
    response_to_json(r.body)
end



"""
Get ticker for general target.
"""
function get_target_ticker(target::String; symbol=nothing)
    url = "$BINANCE_FUTURE_BASE_URL/fapi/v1/ticker/$target"
    if symbol != nothing
        url = "$url?symbol=$symbol"
    end
    request_get(url)
end


"""
get depth
"""
function get_depth(symbol::String; limit=100) # 500(5), 1000(10)
    url = "$BINANCE_FUTURE_BASE_URL/fapi/v1/depth?symbol=$symbol&limit=$limit"
    request_get(url)
end


"""
24hr Ticker Price Change Statistics
https://binance-docs.github.io/apidocs/futures/en/#24hr-ticker-price-change-statistics
"""
get_24hr_ticker(symbol=nothing) = get_target_ticker("24hr", symbol=symbol)


"""
Symbol Price Ticker
https://binance-docs.github.io/apidocs/futures/en/#symbol-price-ticker
"""
get_price_ticker(symbol=nothing) = get_target_ticker("price", symbol=symbol)


"""
Symbol Order Book Ticker
https://binance-docs.github.io/apidocs/futures/en/#symbol-order-book-ticker

"""
get_book_ticker(symbol=nothing) = get_target_ticker("bookTicker", symbol=symbol)


function get_Binance_info()
    url = "https://www.binance.com/fapi/v1/exchangeInfo"
    request_get(url)
end


"""
Get klines of symbol.
intervel can be "1m", "3m", "5m", "15m", "30m", "1h", "2h", "4h", "6h", "8h", "12h", "1d", "3d", "1w", "1M";
limit <= 1500
"""
function get_klines(symbol; start_datetime=nothing, end_datetime=nothing, interval="1m", limit=1000)
    query = "?symbol=$symbol&interval=$interval&limit=$limit"

    if start_datetime != nothing && end_datetime != nothing
        start_time = datetime_to_timestamp(start_datetime)
        end_time = datetime_to_timestamp(end_datetime)
        query = "$query&startTime=$start_time&endTime=$end_time"
    end
    url = "$BINANCE_FUTURE_KLINES_URL$query"
    request_get(url)
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


function websockets(channel::Channel, ws::String, symbol::String)
    
    url = "$BINANCE_FUTURE_WS/$(lowercase(symbol))$ws"
    HTTP.WebSockets.open(url; verbose=false) do io
      while !eof(io);
        put!(channel, response_to_json(readavailable(io)))
    end
  end
end

websockets_agg_trade(channel, symbolg) = websockets(channel, "@aggTrade", symbol)

websockets_trade(channel, symbol) = websockets(channel, "@trade", symbol)

websockets_depth(channel, symbol; level=5) = websockets(channel, "@depth$level", symbol)

websockets_depth_diff(channel, symbol) = websockets(channel, "@depth", symbol)

websockets_ticker(channel, symbol) = websockets(channel, "@ticker", symbol)

websockets_mini_ticker(channel, symbol) = websockets(channel, "@miniTicker", symbol)

websockets_book_ticker(channel, symbol) = websockets(channel, "@bookTicker", symbol)


function websockets_ticker_24hr(channel::Channel)
    url = "$BINANCE_FUTURE_WS/!ticker@arr"
    HTTP.WebSockets.open(url; verbose=false) do io
      while !eof(io);
        put!(channel, response_to_json(readavailable(io)))
    end
  end
end