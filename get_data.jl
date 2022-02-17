#!/usr/bin/env julia
include("src/init.jl")

sybols0 = ["MATIC", "SXP", "1000SHIB", "ADA"]

symbols = [uppercase(symbol) * "USDT" for symbol in sybols0]

# get_agg_trades.(symbols)

for symbol in symbols
    get_agg_trades(symbol, fetch_data_only=true)
end