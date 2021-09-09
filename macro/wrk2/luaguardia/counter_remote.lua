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
package.path = package.path .. ";../../libs/macro/wrk/?.lua"
counter_val = 0
counter = require("counter")
counter = wrapper(counter)

init = function()
    mode = 0
    --if config == nil then
        -- to mode einai mia global pou pairnei 3 times, 0, 1,2
        -- 0 = Remote Vanilla Lua Interpreter
        -- 1 = Remote SGX LuaVM E2E encryption
        -- 2 = Remote SGX LuaVM Xwris encryption
    connect_to_worker(mode)
    --end
    --module_file_name = "out"
    local w = config[1]
    module_file_name = nil
    send_modules(w)
    -- this is the remote offloading :)
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
    local dat = json.encode(a, {indent = false})
    local res = counter.exec(dat) --counter_val, tmp)
    res = json.decode(res)
    res.wr = json.encode(res.wr)
    -- Don't close the worker after the execution :)
--    print("Result: ", res.wr)
--    if config[1] == nil then
--        print("")
--    else
--    end
    counter_val = res.c
    local xx = json.decode(res.wr)
    -- the result of the sgx execution
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

function round(number)
    precision = 2
    local fmtStr = string.format('%%0.%sf',precision)
    number = string.format(fmtStr,number)
    return number
end


done = function(summary, latency, requests)
    reqs_s  = string.sub(tostring(summary.requests/summary.duration), 1, 4)
    trans_s = string.sub(tostring(summary.bytes/summary.duration/1024), 1, 4)

    print("Requests/sec", reqs_s)
    print("Transfer/sec", trans_s .. 'KB')
end
