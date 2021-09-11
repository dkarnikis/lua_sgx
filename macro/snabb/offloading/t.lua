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

function compare(a,b)
    return a < b
end


local config = require("config")
local pcap = require("pcap")
local json = require("dkjson")
local p = config.new()
f = io.open("out", "r")
arg1 = f:read()
arg2 = f:read()



config.app(p, "net1", pcap.SGXReader, arg1)
config.app(p, "net2", pcap.SGXWriter, arg2)
config.link(p, "net1.output -> net2.input")   
local str = json.encode (dump(p), { indent = true })
--print(str)
print(dump(p))
