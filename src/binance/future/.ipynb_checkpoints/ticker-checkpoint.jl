
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
