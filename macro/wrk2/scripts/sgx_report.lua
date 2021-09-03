local json = require("dkjson")
local f = io.open("out", 'r')
local a = f:read("*a")
--print(a)
--print(json.decode(a))
a = json.decode(a)
io.write("------------------------------\n")
local i = 0
for _, p in pairs({ 50, 90, 99, 99.999 }) do
  
  n = a.n[tostring(i)] --latency:percentile(p)
  io.write(string.format("%g%%,%d\n", tonumber(a.p[tostring(i)]), tonumber(n)))
  i = i + 1
end

io.write("------------------------------\n")
