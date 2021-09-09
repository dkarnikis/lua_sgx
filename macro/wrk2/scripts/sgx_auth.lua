local wrk = require("wrk")
local json = require("dkjson")
local f = io.open("out", 'r')
local a = json.decode(f:read("*a"))
-- get the values 
a.w[1].format = wrk.format
-- perform the critical code here
local res = a.w[1].format("GET", a.p)
-- end of critical code
-- remove any references to function entities
a.w[1].format = nil
-- encode the data
result = {r = res, wr = {a.w}}
-- print to stdout so the client can parse them
print(json.encode(result, {indent = true}))