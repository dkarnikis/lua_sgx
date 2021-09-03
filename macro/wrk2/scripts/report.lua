----offload to luajit
--
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

json = require("scripts/dkjson")
done = function(summary, latency, requests)
    local a = {n = {}, p = {}}
    local i = 0
    for _, p in pairs({ 50, 90, 99, 99.999 }) do
        n = latency:percentile(p)
        a.n[i] = n
        a.p[i] = p
        i = i + 1
    end
    local f = io.open("scripts/out", 'w')
    f:write(json.encode(a, {indent = true}))
    f:close()
    cmd="./lua_vm -l -i scripts/sgx_report.lua"
    local h = io.popen(cmd)
    local res = h:read("*a")
    print(res)
    h:close()
end
