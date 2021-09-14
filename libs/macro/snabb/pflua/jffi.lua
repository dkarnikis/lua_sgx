local json =require("dkjson")
local ffi=require("ffi")
function dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

f=io.open('out1', 'r')
arg = f:read("*a")
res=json.decode(arg)
a=res.a
b=res.b
c=res.c
--print(type(a))
--print(type(b))
--print(type(c))
local str = ffi.cast("char *", b) + tonumber(c)
local p = ffi.cast(a, str)[0]
f:close()
local haha=io.open("hahaxd", "w")
haha:write(p) --json.encode(p, {indent=true}))
haha:close()
