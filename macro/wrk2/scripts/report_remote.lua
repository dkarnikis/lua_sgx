-- example dynamic request script which demonstrates changing
-- the request path and a header for each request
-------------------------------------------------------------
-- NOTE: each wrk thread has an independent Lua scripting
-- context and thus there will be one counter per thread

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

json = require("scripts.dkjson")
done = function(summary, latency, requests)
    local a = {n = {}, p = {}}
    local i = 0
    for _, p in pairs({ 50, 90, 99, 99.999 }) do
        n = latency:percentile(p)
        a.n[i] = n
        a.p[i] = p
        i = i + 1
    end
    local f = io.open("out", 'w')
    f:write(json.encode(a, {indent = true}))
    f:close()
    cmd="cd scripts; ./client -p 8888 -s localhost -i sgx_report.lua -n 3 -m wrk.lua -m out -m dkjson.lua > ../xd1; cat ../xd1"
    local h = io.popen(cmd)
    local res = h:read("*a")
    print(res)
    h:close()
end

