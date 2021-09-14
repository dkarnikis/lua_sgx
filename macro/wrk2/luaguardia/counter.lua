-- example dynamic request script which demonstrates changing
-- the request path and a header for each request
-------------------------------------------------------------
-- NOTE: each wrk thread has an independent Lua scripting
-- context and thus there will be one counter per thread
package.path = package.path .. ";../../libs/macro/wrk/?.lua"
package.path = package.path .. ";../libs/?.lua"
counter_val = 0
lua_client = require("lclient")
lua_client.bootstrap()

counter = require("counter")
counter = lua_client.wrapper(counter)

init = function()
    lua_client.connect_to_worker(lua_client.mode)
    lua_client.set_module_file(nil)
    -- send the module info to the client
    lua_client.send_modules(lua_client.get_config()[1])
end

request = function()
    -- write the data into a table and then dump them into a file 
    local tmp = {}
    -- store all the data that cannot be encoded and insert them back after SGX exec
    local missing_entries = {}
    for k,v in pairs(wrk) do
       if (type(v) == "function" or type(v) == "userdata") then
            tmp[k] = nil
            missing_entries[k] = v
        else
            tmp[k] = v;
        end
    end
    local a = {c = counter_val, w = {tmp}}
    local dat = dkjson.encode(a)
    local res = counter.exec(dat) --counter_val, tmp)
    res = dkjson.decode(res)
    res.wr = dkjson.encode(res.wr)
    counter_val = res.c
    local xx = dkjson.decode(res.wr)
    -- the result of the execution
    local result = res.r
    -- got the SGX data, restore the missing function and userdata data
    for k, v in pairs(missing_entries) do
        xx[1][k] = v
    end
    -- restore the original wrk class
    wrk = xx[1]
    -- close the file
    return result
end

done = function(summary, latency, requests)
    
    io.write(string.format("requests: %d,\n", summary.requests))
    io.write(string.format("duration_in_microseconds: %0.2f,\n", summary.duration))
    io.write(string.format("bytes: %d\n", summary.bytes))
    io.write(string.format("requests_per_sec: %0.2f\n", (summary.requests/summary.duration)*1e6))
    io.write(string.format("bytes_transfer_per_sec: %0.2f\n", (summary.bytes/summary.duration)*1e6))
end
