local counter = {} 

counter.exec = function(data)
--    local wrk = require("wrk")
 --   local json = require("dkjson")
    local f = io.open("out", 'r')
    local a = dkjson.decode(f:read("*a"))
    -- get the values 
    local counter_val = a.c
    local path = "/" .. counter_val
    a.w[1].headers["X-Counter"] = counter_val
    counter_val = counter_val + 1
    a.w[1].format = wrk.format
    local res = a.w[1].format(nil, path)
    -- remove any references to function entities
    a.w[1].format = nil
    -- encode the data
    local result = {r = res, wr = a.w, c = counter_val}
    local res = dkjson.encode(result)
    -- print to stdout so the client can parse them
    print(res)
end

return counter
