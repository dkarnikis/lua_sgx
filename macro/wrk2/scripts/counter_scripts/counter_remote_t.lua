-- example dynamic request script which demonstrates changing
-- the request path and a header for each request
-------------------------------------------------------------
-- NOTE: each wrk thread has an independent Lua scripting
-- context and thus there will be one counter per thread
-- open two different servers listening 
json = require("scripts.dkjson")
counter = 0
function setup(thread)
  --os.execute("rm -rf thread_*")
    for i=0, 5, 1 do
        os.execute("mkdir -p thread_"..tostring(id + i))
    end
	print("NIGA")
end
-- setup arguments for remote execution handling
local folder = "thread_".. id.."/"
local fout = folder .."out"
local remote_port = 8888 -- + id
local xd_file = "../"..folder.."xd1"
-- the function that executes at every request
request = function(args)
    -- write the data into a table and then dump them into a file 
    local f = io.open(fout, 'w')
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
    -- store the data in the file for the sgx parsing
    local a = {c = counter, w = {tmp}}
    -- encode it on json so SGX can parse it 
    f:write(json.encode(a))
    f:close()
    -- declare the args for the client
    --cmd="cd scripts; ./client -p ".. remote_port .." -s 139.91.90.18 -i sgx_counter.lua -n 3 -m wrk.lua -m ../".. fout .." -m dkjson.lua" -- > "..xd_file.."; cat "..xd_file
	cmd="cd scripts; ./client -p ".. remote_port .. " -s 139.91.90.18 -i sgx_counter.lua -n 1 -m ../" .. fout .." -g"
    -- spawn the client
    local h = io.popen(cmd)
    -- parse the results
--    local res = json.decode(h:read("*a"))
--    -- get the updated counter
--    counter=res.c
--    -- decode the sgx wrk structure
--    local xx = json.decode(res.wr)
--    -- the result of the sgx execution
--    local result = res.r
--    -- got the SGX data, restore the missing function and userdata data
--    for k, v in pairs(missing_entries) do
--        xx[1][k] = v
--    end
--    wrk = xx[1]
--    -- close the file
--    h:close()
    -- return the results
    return wrk.format(nil, path)
end
