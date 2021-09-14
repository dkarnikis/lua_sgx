local savefile = require("savefile")
local json =require("dkjson")
pkts = savefile.load_packets("arp.pcap")
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
print(json.encode(dump(pkts), { indent = true }))

