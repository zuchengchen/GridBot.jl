"""
Ping to the url.
"""
function ping(url)
    r = HTTP.request("GET", url)
    r.status
end


"""
Convert HTTP response to JSON
"""
function response_to_json(response)
    JSON.parse(String(response))
end


"""
Get the request and convert to json.
"""
function request_get(url)
    response = HTTP.request("GET", url)
    response_to_json(response.body)
end


"""
Convert an order_dict to an string parameter.
"""
function order_dict_to_params(order_dict::Dict)
    params = ""
    for (key, value) in order_dict
        params = "$params&$key=$value"
    end
    params[2:end]
end


"""
Hash the msg with key.
"""
function hmac(key::Vector{UInt8}, msg::Vector{UInt8}, hash, blocksize::Int=64)
    if length(key) > blocksize
        key = hash(key)
    end

    pad = blocksize - length(key)

    if pad > 0
        resize!(key, blocksize)
        key[end - pad + 1:end] = 0
    end

    o_key_pad = key .⊻ 0x5c
    i_key_pad = key .⊻ 0x36

    hash([o_key_pad; hash([i_key_pad; msg])])
end


"""
Sigh the query message with api_secret.x
"""
function do_sign(query, user)
    hash_value = hmac(Vector{UInt8}(user.secret), Vector{UInt8}(query), SHA.sha256)
    bytes2hex(hash_value)
end


"""
Make path if it doesn't exists.
"""
function mk_path(path)
    if !ispath(path)
        mkpath(path)
    end
end

"""
Remove file when it exists.
"""
function rm_file(file)
    if isfile(file)
        rm(file, recursive=true)
    end
end


function mk_save_path(symbol, cache)
    symbol_upper = uppercase(symbol)    
    save_path = "historical_data/$symbol_upper/$cache"
    mk_path(save_path)
    save_path
end


function json_to_dataframe(json_list)
    vcat(DataFrame.(json_list)...)
end


"""
Convert a bool value to 1 or 0.
"""
convert_bool_to_int8(bool) = bool==true ? Int8(1) : Int8(0)
