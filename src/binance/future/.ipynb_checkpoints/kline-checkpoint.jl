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
