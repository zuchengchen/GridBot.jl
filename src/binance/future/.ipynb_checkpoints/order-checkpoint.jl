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