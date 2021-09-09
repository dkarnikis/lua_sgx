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

package.path = package.path .. ";../../libs/macro/wrk/?.lua"
package.path = package.path .. ";../libs/?.lua"
counter_val = 0
counter = require("counter")
counter = wrapper(counter)

init = function()
    connect_to_worker(mode)
    module_file_name = nil
    -- send the module info to the client
    send_modules(config[1])
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
    local dat = dkjson.encode(a, {indent = false})
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
    reqs_s  = string.sub(tostring(summary.requests/summary.duration), 1, 5)
    trans_s = string.sub(tostring(summary.bytes/summary.duration / 1024 / 1000000), 1, 5)
    print("Requests/sec", reqs_s)
    print("Transfer/sec", trans_s .. 'KB')
end
