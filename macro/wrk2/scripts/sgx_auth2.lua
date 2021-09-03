local wrk = require("wrk")
local json = require("dkjson")
local f = io.open("out", 'r')
local a = json.decode(f:read("*a"))
status = a.s
headers = a.h
body = a.b
token = a.t
path = a.p
if not token and status == 200 then
    token = headers["X-Token"]
    path = "/resource"
    headers["X-Token"] = token
end
result = {t = token, p = path, h = {headers}} --, wr = json.encode(a.w, {indent = true})}
print(json.encode(result))
