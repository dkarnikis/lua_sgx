local ffi = require("ffi")
local json = require("dkjson")
local f = io.open("out1", "r")
local arg = f:read("*a")
f:close()
local res = json.decode(arg)
local cast = res.a -- the cast we do
local lua_str = res.b -- the input buffer
local offset = res.c -- the offset
local c_str = ffi.new("unsigned char [10240]", lua_str)
local res = (ffi.cast(cast, c_str + offset))[0]
print(res)

local bit = require("bit")
local d1,c1,b1,a1 = lua_str:byte(offset+1, offset+4)
local num =  bit.rshift(a1, 24) + bit.rshift(b1, 16) + bit.rshift(c1, 8) + d1
print(math.floor(num))
