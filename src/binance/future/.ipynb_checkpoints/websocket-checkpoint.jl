
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