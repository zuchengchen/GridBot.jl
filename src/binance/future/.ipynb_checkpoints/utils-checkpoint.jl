"""
Simple test if Binance future api is online or not.
"""
function ping_future()    
    if ping(BINANCE_FUTURE_PING_URL)==200
        println("Ping succeed.")
    else
        println("Ping failed.")
    end
end


"""
Get Binance server time.
""" 
function get_server_time()
    result = request_get(BINANCE_FUTURE_TIME_URL)
    Dates.unix2datetime(result["serverTime"] / 1000)
end


"""
Get Binance information.
"""
get_Binance_info() = request_get(BINANCE_FUTURE_EXCHANGEINFO_URL)


"""
get depth
"""
function get_depth(symbol::String; limit=100)
    url = "$BINANCE_FUTURE_BASE_URL/fapi/v1/depth?symbol=$symbol&limit=$limit"
    request_get(url)
end
