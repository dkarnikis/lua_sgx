local wrk = require("wrk")
local json = require("dkjson")
local f = io.open("out", 'r')
local a = json.decode(f:read("*a"))
-- get the values 
local counter = a.c
--for k, v in pairs(a.w[1]) do
--    print(k, v)
--    print("||||")
--end
-- perform the critical code here
path = "/" .. counter
a.w[1].headers["X-Counter"] = counter
counter = counter + 1
a.w[1].format = wrk.format
local res = a.w[1].format(nil, path)
-- end of critical code
-- remove any references to function entities
a.w[1].format = nil
-- encode the data
result = {r = res, wr = json.encode(a.w, {indent = true}), c=counter}
-- print to stdout so the client can parse them
print(json.encode(result, {indent = true}))
