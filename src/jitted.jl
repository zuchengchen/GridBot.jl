round_dynamic(n, d) = n == 0.0 ? n : round(n, digits=(d - Int(floor(log10(abs(n)))) - 1))

function format_float(num) 
    str = string(num)
    if endswith(str, ".0")
        str = str[1:end-2]
    end
    str
end


function compress_float(n, d) 
    
    n = n/10^d >= 1 ? round(n) : round_dynamic(n, d)
    nstr = format_float(n)
#     println(nstr)
    if startswith(nstr, "0.")
        nstr = nstr[2:end]
    elseif startswith(nstr, "-0.")
        nstr = "-" * nstr[3:end]
    elseif endswith(nstr, ".0")
        print(nstr)
        nstr = nstr[1:end-4]
    end
    nstr
end


round_up(n, step, safety_rounding=10) = round(ceil(round(n/step, digits=safety_rounding)) * step, digits=safety_rounding)


round_dn(n, step, safety_rounding=10) = round(floor(round(n/step, digits=safety_rounding)) * step, digits=safety_rounding)

round_(n, step, safety_rounding=10) = round(round(n/step) * step, digits=safety_rounding)


calc_diff(x, y) = (x - y)/y

nan_to_0(x) = x == x ? x : 0.0

function calc_ema(prev_ema, new_val, span)
    alpha = 2/(span + 1)
    prev_ema * (1 - alpha) + new_val * alpha
end

calc_ema(alpha, alpha_, prev_ema, new_val) = prev_ema * alpha_ + new_val * alpha

function calc_emas(xs, span)
    emas = zero(xs)
    emas[1] = xs[1]
    for i in 2:length(xs)
        emas[i] = calc_ema(emas[i-1], xs[i], span)
    end
    emas
end

function calc_stds(xs, span)
    stds = zero(xs)
    if length(stds) <= span
        return stds
    end
    xsum = sum(xs[1:span])
    xsum_sq = sum(xs[1:span] .^ 2)
    stds[span] = sqrt((xsum_sq/span) - (xsum/span) .^ 2)
    for i in (span + 1):length(xs)
        xsum += xs[i] - xs[i-span]
        xsum_sq += xs[i]^2 - xs[i-span]^2
        stds[i] = sqrt((xsum_sq/span) - (xsum/span) .^ 2)
    end
    stds
end

function calc_emas_(alpha, alpha_, chunk_size, xs_, first_val, kc_)
    emas_ = zeros(chunk_size)
    emas_[1] = first_val
    for i in 2:min(length(xs_) - kc_, length(emas_))
        emas_[i] = emas_[i-1] * alpha_ + xs_[kc_+i] * alpha
    end
    emas_
end

function calc_first_stds(chunk_size, span, xs_)
    stds_ = zeros(chunk_size)
    xsum_ = sum(xs_[1:span])
    xsum_sq_ = sum((xs_[1:span] .^ 2))
    for i in (span+1):chunk_size
        xsum_ += xs_[i] - xs_[i-span]
        xsum_sq_ += xs_[i]^2 - xs_[i-span]^2
        stds_[i] = sqrt((xsum_sq_/span) - (xsum_/span) .^ 2)
    end
    stds_, xsum_, xsum_sq_
end

function calc_stds_(chunk_size, span, xs_, xsum_, xsum_sq_, kc_)
    new_stds = zeros(chunk_size)
    xsum_ += xs_[kc_] - xs_[kc_-span]
    xsum_sq_ += xs_[kc_]^2 - xs_[kc_-span]^2
    new_stds[1] = sqrt((xsum_sq_/span) - (xsum_/span)^2)
    for i in 2:chunk_size
        xsum_ += xs_[kc_+i] - xs_[kc_+i-span]
        xsum_sq_ += xs_[kc_+i]^2 - xs_[kc_+i-span]^2
        new_stds[i] = sqrt((xsum_sq_/span) - (xsum_/span)^2)
    end
    new_stds, xsum_, xsum_sq_
end

function calc_min_entry_qty(price, inverse, qty_step, min_qty, min_cost, contract_multiplier) 
    contract_multiplier = inverse ? contract_multiplier : 1
    qty = round_up(min_cost * (price/contract_multiplier), qty_step)
    max(min_qty, qty)
end


function calc_qty_from_margin(
        margin, 
        price,
        inverse, 
        qty_step, 
        contract_multiplier, 
        leverage
    )
    if inverse
        return round_dn(margin * leverage * price/contract_multiplier, qty_step)
    else
        return round_dn(margin * leverage/price, qty_step)
    end
end


function calc_initial_entry_qty(
        balance,
        price,
        available_margin,
        volatility,
        inverse, 
        qty_step, 
        min_qty,
        min_cost, 
        contract_multiplier, 
        leverage,
        qty_pct, 
        volatility_qty_coeff
        )
    min_entry_qty = calc_min_entry_qty(price, inverse, qty_step, min_qty, min_cost, contract_multiplier)
    
    if inverse
        available_qty = available_margin * leverage * price/contract_multiplier
        initial_entry_qty = (balance/contract_multiplier) * price * leverage * qty_pct * (1 + volatility * volatility_qty_coeff)
    else
        available_qty = available_margin * leverage/price
        initial_entry_qty = (balance/price) * leverage * qty_pct * (1 + volatility * volatility_qty_coeff)
    end
    
    qty_ = min(available_qty, max(min_entry_qty, initial_entry_qty))
    qty = round_dn(qty_, qty_step)
    qty >= min_entry_qty ? qty : 0.0
end


function calc_reentry_qty(
        psize, 
        price, 
        available_margin, 
        inverse, 
        qty_step, 
        min_qty,
        min_cost, 
        contract_multiplier, 
        ddown_factor, 
        leverage
    )
    
    min_entry_qty = calc_min_entry_qty(price, inverse, qty_step, min_qty, min_cost, contract_multiplier)
    contract_multiplier = inverse ? contract_multiplier : 1
    available_qty = round_dn(available_margin * leverage * (price/contract_multiplier/price), qty_step)
    reentry_qty = max(min_entry_qty, round_dn(abs(psize) * ddown_factor, qty_step))
    qty_ = min(available_qty, reentry_qty)
    qty_ >= min_entry_qty ? qty_ : 0.0
end

function calc_new_psize_pprice(psize, pprice, qty, price, qty_step)
    
    if qty == 0.0
        return psize, pprice
    end
    
    new_psize = round_(psize + qty, qty_step)
    
    if new_psize == 0.0
        return 0.0, 0.0
    end
    
    new_psize, nan_to_0(pprice) * (psize/new_psize) + price * (qty/new_psize)
end


function calc_long_pnl(entry_price, close_price, qty, inverse, contract_multiplier)
    if inverse
        if (entry_price == 0.0) || (close_price == 0.0)
            return 0.0
        end
        return abs(qty) * contract_multiplier * (1 / entry_price - 1 / close_price)
    else
        return abs(qty) * (close_price - entry_price)
    end
end

function calc_shrt_pnl(entry_price, close_price, qty, inverse, contract_multiplier)
    if inverse
        if (entry_price == 0.0) || (close_price == 0.0)
            return 0.0
        end
        return abs(qty) * contract_multiplier * (1/close_price - 1/entry_price)
    else
        return abs(qty) * (entry_price - close_price)
    end
end

calc_cost(qty, price, inverse, contract_multiplier) =  inverse ? abs(qty/price) * contract_multiplier : abs(qty * price)


calc_margin_cost(qty, price, inverse, contract_multiplier, leverage) = calc_cost(qty, price, inverse, contract_multiplier)/leverage


function calc_available_margin(
        balance,
        long_psize,
        long_pprice,
        shrt_psize,
        shrt_pprice,
        last_price,
        inverse, 
        contract_multiplier, 
        leverage
        ) 
    
    used_margin = 0.0
    equity = balance
    
    if long_pprice != 0.0
        long_psize_real = long_psize * contract_multiplier
        equity += calc_long_pnl(long_pprice, last_price, long_psize_real, inverse, contract_multiplier)
        used_margin += calc_cost(long_psize_real, long_pprice, inverse, contract_multiplier)/leverage
    end
    
    if shrt_pprice != 0.0
        shrt_psize_real = shrt_psize * contract_multiplier
        equity += calc_shrt_pnl(shrt_pprice, last_price, shrt_psize_real, inverse, contract_multiplier)
        used_margin += calc_cost(shrt_psize_real, shrt_pprice, inverse, contract_multiplier)/leverage
    end
    
    max(0.0, equity - used_margin)
end



function calc_liq_price_binance(
        balance,
        long_psize,
        long_pprice,
        shrt_psize,
        shrt_pprice,
        inverse, 
        contract_multiplier, 
        leverage)
    abs_long_psize = abs(long_psize)
    abs_shrt_psize = abs(shrt_psize)
    long_pprice = nan_to_0(long_pprice)
    shrt_pprice = nan_to_0(shrt_pprice)
    if inverse
        mml = 0.02
        mms = 0.02
        numerator = abs_long_psize * mml + abs_shrt_psize * mms + abs_long_psize - abs_shrt_psize
        long_pcost = long_pprice > 0.0 ? (abs_long_psize / long_pprice) : 0.0
        shrt_pcost = shrt_pprice > 0.0 ? (abs_shrt_psize / shrt_pprice) : 0.0
        denom = balance / contract_multiplier + long_pcost - shrt_pcost
        if denom == 0.0
            return 0.0
        end
        return max(0.0, numerator / denom)
    else
        mml = 0.01
        mms = 0.01
        # tmm = max(long_pos_margin, shrt_pos_margin)
        numerator = (balance - abs_long_psize * long_pprice + abs_shrt_psize * shrt_pprice)
        denom = (abs_long_psize * mml + abs_shrt_psize * mms - abs_long_psize + abs_shrt_psize)
        if denom == 0.0
            return 0.0
        end
        return max(0.0, numerator / denom)
    end
end

function calc_bankruptcy_price(
        balance,
        long_psize,
        long_pprice,
        shrt_psize,
        shrt_pprice,
        inverse, 
        contract_multiplier
    )
    long_pprice = nan_to_0(long_pprice)
    shrt_pprice = nan_to_0(shrt_pprice)
    long_psize *= contract_multiplier
    abs_shrt_psize = abs(shrt_psize) * contract_multiplier
    
    if inverse
        shrt_cost = (shrt_pprice > 0.0) ? (abs_shrt_psize/shrt_pprice) : 0.0
        long_cost = (long_pprice > 0.0) ? (long_psize/long_pprice) : 0.0
        denominator = (shrt_cost - long_cost - balance)
        if denominator == 0.0
            return 0.0
        end
        liq_price = (abs_shrt_psize - long_psize) / denominator
    else
        denominator = long_psize - abs_shrt_psize
        if denominator == 0.0
            return 0.0
        end
                        
        liq_price = (-balance + long_psize * long_pprice - abs_shrt_psize * shrt_pprice) / denominator
    end
    
    max(0.0, liq_price)
end