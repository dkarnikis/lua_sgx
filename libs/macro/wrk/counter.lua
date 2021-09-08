local counter = {} 

counter.exec = function(dat)
    obj = dkjson.decode(dat)
    -- get the values 
    local counter_val = obj.c
    local path = "/" .. counter_val
    obj.w[1].headers["X-Counter"] = counter_val
    counter_val = counter_val + 1
    obj.w[1].format = wrk.format
    local res = obj.w[1].format(nil, path)
    -- remove any references to function entities
    obj.w[1].format = nil
    -- encode the data
    local result = {r = res, wr = obj.w, c = counter_val}
    local res = dkjson.encode(result)
    -- print to stdout so the client can parse them
    print(res)
end

return counter
