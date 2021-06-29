lua_code = arg[1]
local functions = {}
-- load  the libraries
local client = require('foo')
local dkjson = require ("dkjson")
local utils = require("utils")
local config = utils.lines_from("config")
local remote_servers = #config
local task_counter = 0
if lua_code == nil then
    print("Give a lua code")
    os.exit(1)
end

local function pick_worker() 
    task_counter = task_counter + 1
    return (task_counter % remote_servers) + 1
end

local function offload (...)
    local args = table.pack(...)
    local json = dkjson.encode(args, { indent = true})
    json = 'json = \'' .. json .. '\''
    local wrk = pick_worker()
    --local spawn_wrk = remote_worker()
    local item = config[wrk]
    client.lsend_code(item.socket, json, item.aes_key);
    res = client.lrecv_response(item.socket, item.aes_key);
    print(res)
    return res
end

function wrapper (obj)
    if type(obj) == "function" then
        return function(...)
            if run_local == true then
                return obj(...)
            end

            return offload(functions[obj], ...)
        end
    elseif type(obj) == "table" then
        for k,v in pairs(obj) do
            functions[v] = k
            obj[k] = wrapper(v)
        end 
    end
    return obj
end

local run_local = false
res = loadfile(lua_code)()

