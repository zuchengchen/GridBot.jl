"""
round_up(18.654, 15)
"""
round_up(n, step, digits=10) = round(ceil(n / step) * step, digits=digits)


"""
round_dn(16.77, 20)
"""
round_dn(n, step, digits=10) = round(floor(n / step) * step, digits=digits)

"""
round_(19, 20)
"""
round_(n, step, digits=10) = round(round(n / step) * step, digits=digits)


"""
calc_diff(-2, -2.3)
"""
calc_diff(x, y) = abs(x - y) / abs(y)


sort_dict_keys(dict::Dict) = sort(dict)
sort_dict_keys(dicts::Array) = [sort(dicts) for dict in dicts]
sort_dict_keys(non_dict) = non_dict


calc_min_qty_linear(qty_step, min_qty, min_cost, price) = max(min_qty, round_up(min_cost / price, qty_step))

calc_long_pnl_linear(entry_price, close_price, qty) = abs(qty) * (close_price - entry_price)

calc_shrt_pnl_linear(entry_price, close_price, qty) = abs(qty) * (entry_price - close_price)

calc_cost_linear(qty, price) = abs(qty * price)

calc_margin_cost_linear(leverage, qty, price) = calc_cost_linear(qty, price) / leverage

calc_max_pos_size_linear(leverage, balance, price) = (balance / price) * leverage

function calc_min_entry_qty_linear(qty_step, min_qty, min_cost, entry_qty_pct, leverage, balance, price) 
    min_qty = calc_min_qty_linear(qty_step, min_qty, min_cost, price)
    max_pos_size = calc_max_pos_size_linear(leverage, balance, price)
    calc_min_entry_qty(min_qty, qty_step, max_pos_size, entry_qty_pct)
end


calc_no_pos_bid_price(price_step, ema_spread, ema, highest_bid) = min(highest_bid, round_dn(ema * (1 - ema_spread), price_step))

calc_no_pos_ask_price(price_step, ema_spread, ema, lowest_ask) = max(lowest_ask, round_up(ema * (1 + ema_spread), price_step))

function calc_pos_reduction_qty(qty_step, stop_loss_pos_reduction, pos_size) 
    aps = abs(pos_size)
    min(aps, round_up(aps * stop_loss_pos_reduction, qty_step))
end

calc_min_close_qty(qty_step, min_qty, min_close_qty_multiplier, min_entry_qty) = max(min_qty, round_dn(min_entry_qty * min_close_qty_multiplier, qty_step))

function calc_long_reentry_price(price_step, grid_spacing, grid_coefficient,
        balance, pos_margin, pos_price)
    modified_grid_spacing = grid_spacing * (1 + pos_margin / balance * grid_coefficient)
    round_dn(pos_price * (1 - modified_grid_spacing), round_up(pos_price * grid_spacing / 4, price_step))
end

function calc_shrt_reentry_price(price_step, grid_spacing, grid_coefficient,
        balance, pos_margin, pos_price)
    modified_grid_spacing = grid_spacing * (1 + pos_margin / balance * grid_coefficient)
    round_up(pos_price * (1 + modified_grid_spacing), round_up(pos_price * grid_spacing / 4, price_step))
end

calc_min_entry_qty(min_qty, qty_step, leveraged_balance_ito_contracts, qty_balance_pct) = max(min_qty, round_dn(leveraged_balance_ito_contracts * abs(qty_balance_pct), qty_step))

function calc_reentry_qty(qty_step, ddown_factor, min_entry_qty, max_pos_size, pos_size)
    abs_pos_size = abs(pos_size)
    qty_available = max(0.0, round_dn(max_pos_size - abs_pos_size, qty_step))
    min(qty_available, max(min_entry_qty, round_dn(abs_pos_size * ddown_factor, qty_step)))
end


function calc_long_closes(price_step, qty_step, min_qty, min_markup, max_markup, pos_size,
        pos_price, lowest_ask, n_orders=10, single_order_price_diff_threshold=0.003)
    n_orders = Int(round(min(n_orders, pos_size / min_qty)))

    prices = range(pos_price * (1 + min_markup), pos_price * (1 + max_markup), length=n_orders)
    
    prices = round_up.(prices, price_step)

    unique!(prices)
    prices = prices[prices .>= lowest_ask]
    len_prices = length(prices)
    
    if len_prices == 0
        return [-pos_size], [max(lowest_ask, round_up(pos_price * (1 + min_markup), price_step))]
    elseif len_prices == 1
        return [-pos_size], prices
    elseif calc_diff(prices[1], prices[0]) > single_order_price_diff_threshold
        # too great spacing between prices, return single order
        return [-pos_size], [max(lowest_ask, round_up(pos_price * (1 + min_markup), price_step))]
    end
    
    qtys = repeat([pos_size / len_prices], len_prices)
    qtys = round_up.(qtys, qty_step)
    qtys_sum = sum(qtys)
    
    while qtys_sum > pos_size
        for i in 1:length(qtys)
            qtys[i] = round_(qtys[i] - qty_step, qty_step)
            qtys_sum = round_(qtys_sum - qty_step, qty_step)
            if qtys_sum <= pos_size
                break
            end
        end
    end
    qtys * -1, prices
end


function calc_shrt_closes(price_step, qty_step, min_qty, min_markup, max_markup, pos_size,
        pos_price, highest_bid, n_orders=10, single_order_price_diff_threshold=0.003)
    abs_pos_size = abs(pos_size)
    n_orders = int(round(min(n_orders, abs_pos_size / min_qty)))

    prices = range(pos_price * (1 - min_markup), pos_price * (1 - max_markup), length=n_orders)
    prices = round_dn.(prices, price_step)

    unique!(prices)
    prices = sort(prices[prices .<= highest_bid], rev=true)
    len_prices = length(prices)
    
    if len_prices == 0
        return [-pos_size], [min(highest_bid, round_dn(pos_price * (1 - min_markup), price_step))]
    elseif len_prices == 1
        return [-pos_size], prices
    elseif calc_diff(prices[0], prices[1]) > single_order_price_diff_threshold
        # too great spacing between prices, return single order
        return [-pos_size], [min(highest_bid, round_dn(pos_price * (1 - min_markup), price_step))]
    end
    
    qtys = repeat([abs_pos_size / length(prices)], length(prices))
    qtys = round_up.(qtys, qty_step)
    qtys_sum = sum(qtys)
    
    while qtys_sum > abs_pos_size
        for i in length(qtys):-1:1
            qtys[i] = round_(qtys[i] - qty_step, qty_step)
            qtys_sum = round_(qtys_sum - qty_step, qty_step)
            if qtys_sum <= abs_pos_size
                break
            end
        end
    end
    qtys, prices
end
