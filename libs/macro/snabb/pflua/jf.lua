local json =require("dkjson")
local bit = require("bit")
local f = io.open('out1', 'r')
local arg = f:read("*a")
local res = json.decode(arg)
local a = res.a
local b = res.b
local c = res.c
f:close()
--local haha=io.open("hahaxd", "w")
c = tonumber(c)
local d1,c1,b1,a1 = b:byte(c+1, c+4)
local num =  bit.lshift(a1, 24) + bit.lshift(b1, 16) + bit.lshift(c1, 8) + d1
print(math.floor(num))
