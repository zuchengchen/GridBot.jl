# https://www.binancezh.cc/en/markets
symbols_125_max_leverage = ["BTCUSDT"]
symbols_100_max_leverage = ["ETHUSDT"]
symbols_75_max_leverage = ["ADAUSDT", "BNBUSDT", "DOTUSDT", "EOSUSDT", "ETCUSDT", 
            "LINKUSDT", "LTCUSDT", "TRXUSDT", "XLMUSDT", "XMRUSDT", "XRPUSDT", 
            "XTZUSDT", "BCHUSDT"]
symbols_50_max_leverage = ["AAVEUSDT", "ALGOUSDT", "ALPHAUSDT", "ATOMUSDT", "AVAXUSDT", 
            "AXSUSDT", "BALUSDT", "BANDUSDT", "BATUSDT", "BELUSDT", "BLZUSDT", 
            "BZRXUSDT", "COMPUSDT", "CRVUSDT", "CVCUSDT", "DASHUSDT", "DEFIUSDT", 
            "DOGEUSDT", "EGLDUSDT", "ENJUSDT", "FILUSDT", "FLMUSDT", "FTMUSDT", 
            "HNTUSDT", "ICXUSDT", "IOSTUSDT", "IOTAUSDT", "KAVAUSDT", "KNCUSDT", 
            "KSMUSDT", "LRCUSDT", "MATICUSDT", "MKRUSDT", "NEARUSDT", "NEOUSDT", 
            "OCEANUSDT", "OMGUSDT", "ONTUSDT", "QTUMUSDT", "RENUSDT", "RLCUSDT",
            "RSRUSDT", "RUNEUSDT", "SNXUSDT", "SOLUSDT", "SRMUSDT", "STORJUSDT",
            "SUSHIUSDT", "SXPUSDT", "THETAUSDT", "TOMOUSDT", "TRBUSDT", "UNIUSDT",
            "VETUSDT", "WAVESUSDT", "YFIIUSDT", "YFIUSDT", "ZECUSDT", "ZILUSDT", 
            "ZRXUSDT", "ZENUSDT", "SKLUSDT", "GRTUSDT", "1INCHUSDT", "SFPUSDT"]
symbols_50_max_leverage_2 = ["CTKUSDT"]


"""
symbol, pos_size_ito_usdt = "ADAUSDT", 1e6
get_maintenance_margin_rate(symbol, pos_size_ito_usdt)
https://www.binance.com/en/support/faq/b3c689c1f50a44cabb3a84e663b81d93
"""
function get_maintenance_margin_rate(symbol, notional_value)
    if symbol in symbols_125_max_leverage
        kvs = [(50_000, 0.004), (250_000, 0.005), (1_000_000, 0.01), (5_000_000, 0.025), 
            (20_000_000, 0.05), (50_000_000, 0.1), (100_000_000, 0.125), (200_000_000, 0.15),
            (10^8, 0.25)]
    elseif symbol in symbols_100_max_leverage
        kvs = [(10_000, 0.005), (100_000, 0.0065), (500_000, 0.01), (1_000_000, 0.02), 
            (2_000_000, 0.05), (5_000_000, 0.1), (10_000_000, 0.125), (20_000_000, 0.15),
            (10^8, 0.25)]
    elseif symbol in symbols_75_max_leverage
        kvs = [(10_000, 0.0065), (50_000, 0.01), (200_000, 0.02), (1_000_000, 0.05), 
            (2_000_000, 0.1), (5_000_000, 0.125), (10_000_000, 0.15), (10^8, 0.25)]
    elseif symbol in symbols_50_max_leverage
        kvs = [(5_000, 0.01), (25_000, 0.025), (100_000, 0.05), (250_000, 0.1), 
            (1_000_000, 0.125), (10^8, 0.5)]
    else
        error("Unknown symbol $symbol.")
    end        
        
    for kv in kvs
        if notional_value < kv[1]
            return kv[2]
        end
    end
end

"""
symbol, leverage = "BTCUSDT", 10
get_max_pos_size_ito_usdt(symbol, leverage)
"""
function get_max_pos_size_ito_usdt(symbol, leverage::Int)
    
    if symbol in symbols_125_max_leverage
        kvs = [(100, 50000), (50, 250000), (20, 1000000), (10, 5000000), 
            (5, 20000000), (4, 50000000), (3, 100000000), (2, 200000000)]
    elseif symbol in symbols_100_max_leverage
        kvs = [(75, 10000), (50, 100000), (25, 500000), (10, 1000000), 
            (5, 2000000), (4, 5000000), (3, 10000000), (2, 20000000)]
    elseif symbol in symbols_75_max_leverage
        kvs = [(50, 10000), (25, 50000), (10, 250000), (5, 1000000), 
            (4, 2000000), (3, 5000000), (2, 10000000)]
    elseif symbol in symbols_50_max_leverage
        kvs = [(20, 5000), (10, 25000), (5, 100000), (2, 250000), (1, 1000000)]
    elseif symbol in symbols_50_max_leverage_2
        kvs = [(10, 5000), (5, 25000), (4, 100000), (2, 250000), (1, 1000000)]
    else
        error("Unknown symbol $symbol.")
    end
    
    for kv in kvs
        if leverage > kv[1]
            return kv[2]
        end
    end
    return 9e12
end


"""
https://www.binance.com/en/support/faq/b3c689c1f50a44cabb3a84e663b81d93
balance, pos_size, pos_price, leverage = 99.9995, 100, 1.15097, 20
calc_cross_long_liq_price(balance, pos_size, pos_price, leverage)
"""
function calc_cross_long_liq_price(symbol, wallet_balance, pos_size, entry_price, leverage)
    if pos_size == 0.0
        return 0.0
    end
    
    notional_value = pos_size * entry_price
    mmr = get_maintenance_margin_rate(symbol, notional_value)
    result = (wallet_balance - notional_value) / pos_size / (mmr - 1)
    result > 0 ? result : 0.0
end


"""
https://www.binance.com/en/support/faq/b3c689c1f50a44cabb3a84e663b81d93
balance, pos_size, pos_price, leverage = 100.96, -12, 1.104, 20
calc_cross_shrt_liq_price(balance, pos_size, pos_price, leverage)
"""
function calc_cross_shrt_liq_price(wallet_balance, pos_size, entry_price, leverage)
    if pos_size == 0.0
        return 0.0
    end
    pos_size = abs(pos_size)
    notional_value = pos_size * entry_price
    mmr = get_maintenance_margin_rate(symbol, notional_value)
    result = (wallet_balance + notional_value) / pos_size / (mmr + 1)
    result > 0 ? result : 0.0
end



