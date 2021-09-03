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


counter = 0



request = function()
    -- write the data into a table and then dump them into a file 
    local f = io.open("out", 'w')
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
--    for k, v in pairs(wrk) do
--        print(k, v)
--    end

    local a = {c = counter, w = {tmp}}
    f:write(json.encode(a))
    f:close()
    -- spawn the lua vm

    cmd="cp out scripts/;./lua_vm -t -l scripts/sgx_counter.lua"-- > xd1;cat xd1" --sed -i '$ d' xd1; cat xd1"
    local h = io.popen(cmd)
    local res = json.decode(h:read("*a"))
    counter=res.c
--    print("-----------------------------")
    local xx = json.decode(res.wr)
    -- the result of the sgx execution
    local result = res.r
    -- got the SGX data, restore the missing function and userdata data
    for k, v in pairs(missing_entries) do
        xx[1][k] = v
    end
--    for k, v in pairs(xx[1]) do
--        if (type(v) == "table") then
--            for k2,v2 in pairs(v) do
--                print(k2, v2)
--            end
--        end
--        print(k, v, "||")
--    end
    -- restore the original wrk class
    wrk = xx[1]
    -- close the file
    h:close()
    return result
end

