local counter = 0
local threads = {}
function setup(thread)
    thread:set("id", counter)
    table.insert(threads, thread)
    counter = counter + 1
end
json = require("scripts.dkjson")
done = function(summary, latency, requests)
    local id 
    for index, thread in ipairs(threads) do
        id = thread:get("id") 
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
        port = 8888 + id
        cmd="cp out scripts/; cd scripts; ./client -p ".. port .." -s 139.91.90.168 -i sgx_report.lua -e -n 3 -m wrk.lua -m out -m dkjson.lua > ../xd1; cat ../xd1"
        local h = io.popen(cmd)
        local res = h:read("*a")
        print(res)
        h:close()
    end
end

