local json = require ("dkjson")
local pcap = require("pcap")
-- dump a table entries and data
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

-- command to execute
print(pcap.SGXReader)
cmd=("./lua_vm -l t.lua > xd; sed -i '$ d' xd; cat xd")
local handle = io.popen(cmd)
local result = handle:read("*a")
handle:close()
io.popen("rm -f xd;"):close();
--io.write(result)
local str = json.decode (result)
print(str)
