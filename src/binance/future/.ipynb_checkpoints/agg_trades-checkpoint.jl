const sleep_time = 0.3

"""
Fetch the original agg trades.
"""
function _get_agg_trades(symbol; start_datetime=nothing, end_datetime=nothing, from_id=nothing, limit=1000)
    query = "?symbol=$symbol&limit=$limit"

    if start_datetime != nothing 
        start_time = datetime_to_timestamp(start_datetime)
        query = "$query&startTime=$start_time"
    end
    
    if end_datetime != nothing 
        end_time = datetime_to_timestamp(end_datetime)
        query = "$query&endTime=$end_time"
    end
    
    if from_id != nothing
        query = "$query&fromID=$from_id"
    end
    
    url = "$BINANCE_FUTURE_AGGTRADES_URL$query"
    request_get(url)    
end


"""
Get the refined agg trades dataframe.
"""
function get_refined_agg_trades(symbol; start_datetime=nothing, end_datetime=nothing, from_id=nothing, limit=1000)
    original_agg_trades = _get_agg_trades(symbol, start_datetime=start_datetime, end_datetime=end_datetime, from_id=from_id, limit=limit)
    trades = refined_agg_trade.(original_agg_trades) 
    df = json_to_dataframe(trades)
end


"""
Get the start datetime of the symbol.
"""
function get_agg_trade_start_datetime(symbol)
    trade = _get_agg_trades(symbol; from_id=1, limit=1)[end]
    _ts = trade["T"]
    dt = timestamp_to_datetime(_ts)
end


"""
Get the agg trade id of the datetime.
"""
function get_agg_trade_id(symbol, datetime)
    step = 10^5
    _dt = Dates.DateTime(datetime)
    current_dt = datetime_now()
    if _dt > current_dt
        println("$_dt is latter than current time!")
        println("Using current datetime of $current_dt")
        _dt = current_dt 
    end    
    
    earliest_dt = get_agg_trade_start_datetime(symbol)
    
    if _dt < earliest_dt
        println("Datetime is earlier than the earliest time of $symbol !")
        println("Using the earliest datetime of $earliest_dt")
        _dt = earliest_dt
    end    
    
    trade = _get_agg_trades(symbol, start_datetime=_dt, limit=1)[end]
    id = trade["a"]
end


"""
Convert the agg trade dict to ordered dict with appropriate data type.
"""
function refined_agg_trade(agg_trade::Dict)    
    OrderedDict(
    "trade_id"        =>   agg_trade["a"],
    "price"           =>   parse(Float64, agg_trade["p"]),
    "qty"             =>   parse(Float64, agg_trade["q"]),
    "timestamp"       =>   agg_trade["T"],
    "is_buyer_maker"  =>   convert_bool_to_int8(agg_trade["m"])
    )
end


"""
Get 1e3 or less agg trades from from_id.
"""
function get_less_than_1e3_agg_trades(symbol, from_id, end_id=nothing)
    
    if end_id == nothing
        end_id = from_id + 10^3 - 1    
    end
    
    from_id_div, from_id_rem = divrem(from_id, 10^5)
    from_id_outer = from_id_div * 10^5 + 1
    end_id_outer = from_id_outer + 10^5 - 1
    cache_path = mk_save_path(symbol, "cache")
    cache_file = "$cache_path/$from_id_outer-$end_id_outer.csv"
    
#     println("Fetch agg trades of $symbol with id from $from_id to $end_id ...")
    # load from cache file if it exists
    if isfile(cache_file)
        df = CSV.read(cache_file, DataFrame)
        return df[from_id_rem:(from_id_rem + end_id - from_id), :]    
    end    
    
    intervel_ids = end_id - from_id + 1
    if (rem(from_id, 10^3) == 1) & (intervel_ids == 10^3)
        save_path = mk_save_path(symbol, "subcache")
        save_file = "$save_path/$from_id-$end_id.csv"
        if isfile(save_file)
            df = CSV.read(save_file, DataFrame)
        else
            df = get_refined_agg_trades(symbol, from_id=from_id, limit=intervel_ids)
            CSV.write(save_file, df)
        end
    else
        df = get_refined_agg_trades(symbol, from_id=from_id, limit=intervel_ids)
    end
    sleep(sleep_time)
    
    df
end


"""
Get 1e5 or less agg trades from from_id.
"""
function get_less_than_1e5_agg_trades(symbol, from_id, end_id=nothing)
    
    step = 10^3
    if end_id == nothing
        end_id = from_id + 10^5 - 1    
    end
    
    if end_id < from_id
        return Any[]
    end
    
    from_id_div, from_id_rem = divrem(from_id, step)
    end_id_div, end_id_rem = divrem(end_id, step)
    intervel_ids = end_id - from_id + 1
    
    if (rem(from_id, 10^5) == 1) & (intervel_ids == 10^5)
        save_path = mk_save_path(symbol, "cache")
        save_file = "$save_path/$from_id-$end_id.csv"
        if isfile(save_file)
#             println("Skip $symbol trades with id from $from_id to $end_id ...")
            df = CSV.read(save_file, DataFrame)
        else
#             println("Fetch agg trades of $symbol with id from $from_id to $end_id ...")
            new_from_id = from_id + step
            df = get_less_than_1e3_agg_trades(symbol, from_id)
            for id in new_from_id:step:(end_id - step + 1)
                append!(df, get_less_than_1e3_agg_trades(symbol, id))
            end
            CSV.write(save_file, df)
            subcache_path = mk_save_path(symbol, "subcache")
            for id in from_id:step:(end_id - step + 1)
                file = "$subcache_path/$id-$(id+999).csv"
                rm_file(file)
            end
        end
    else
        if (from_id_div == end_id_div) & (from_id_rem != 0)
            df = get_less_than_1e3_agg_trades(symbol, from_id, end_id)
        else
            first_end_id = (from_id_rem == 0 ? from_id : (from_id_div + 1) * step)
            df = get_less_than_1e3_agg_trades(symbol, from_id, first_end_id)
            for id in (first_end_id + 1):step:(end_id_div * step)
                append!(df, get_less_than_1e3_agg_trades(symbol, id))
            end
            if end_id_rem > 0
                append!(df, get_less_than_1e3_agg_trades(symbol, end_id_div * step + 1, end_id))
            end
        end
    end
    
    df
end

"""
Fetch agg trades of symbol given the start datetime and end datetime.
"""
function get_agg_trades(symbol, start_datetime=nothing, end_datetime=nothing; fetch_data_only=false)
    ping_future()
    rm_saved_data(symbol)
    
    step = 10^5
    
    if start_datetime == nothing
        start_datetime = get_agg_trade_start_datetime(symbol)
    else
        start_datetime = Dates.DateTime(start_datetime)
    end
    
    if end_datetime == nothing
        end_datetime = datetime_now() - Dates.Minute(1)
    else
        end_datetime = Dates.DateTime(end_datetime)
    end
    
    from_id = get_agg_trade_id(symbol, start_datetime)
    end_id = get_agg_trade_id(symbol, end_datetime)
    
    println("Fetch ticks of $symbol from $start_datetime to $end_datetime...")
    
    if start_datetime > end_datetime
        error("Start time should not be latter than end time!!!")
    end
    
    println("Fetch ticks of $symbol with id from $from_id to $end_id ...")
    println("-----------------------------------------------")
    from_id_div, from_id_rem = divrem(from_id, step)
    end_id_div, end_id_rem = divrem(end_id, step)
    intervel_ids = end_id - from_id + 1
    if (from_id_div == end_id_div) & (from_id_rem != 0)
        df = get_less_than_1e5_agg_trades(symbol, from_id, end_id)
    else
        first_end_id = (from_id_rem == 0 ? from_id : (from_id_div + 1) * step)
        df = get_less_than_1e5_agg_trades(symbol, from_id, first_end_id)
        @showprogress "Fetching ticks..." for id in (first_end_id + 1):step:(end_id_div * step)
            df0 = get_less_than_1e5_agg_trades(symbol, id)
            if !fetch_data_only  
                append!(df, df0)
            end
        end
        if end_id_rem > 0
            append!(df, get_less_than_1e5_agg_trades(symbol, end_id_div * step + 1, end_id))
        end
    end
    println("Fetch ticks... Done!")
    println("\n")
    df
end


"""
Remove the data dir of symbol.
"""
function rm_saved_data(symbol)
    symbol_upper = uppercase(symbol)
    save_path = "historical_data/$symbol_upper/data"
    rm_file(save_path)
end