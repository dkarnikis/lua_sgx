lua_code = arg[1]
mode = 1 --tonumber(arg[2])
functions = {}
results = {}
current_tag = nil
-- load  the libraries
local client = require('foo')
local dkjson = require ("dkjson")
--utils = require("utils")
--config = utils.lines_from("config", mode)
--local remote_servers = #config
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
    --local wrk = pick_worker()
    --local spawn_wrk = remote_worker()
    local item = config[1]
    -- remote 'local lua'
    if mode == 0 then
        client.lsend_code(item.socket, json); --, item.aes_key);
        res = client.lrecv_response(item.socket);
    -- remote 'e2e encrypted sgx'
    elseif mode == 1 then
        client.lsend_code(item.socket, json, item.aes_key);
        res = client.lrecv_response(item.socket, item.aes_key);
    -- remote 'local sgx'
    elseif mode == 2 then
        client.lsend_code(item.socket, json); --, item.aes_key);
        res = client.lrecv_response(item.socket);
    end
    timer = client.lrecv_response(item.socket);
    local reg = string.gmatch(timer, '([^ ]+)')
    local obj = {
        e2e = reg(),
        nw = reg(),
        init = reg(),
        exec = reg()
    }
    local fname = args[1]
    table.insert(results[fname][current_tag], obj)
    return res
end

function wrapper (obj)
    if type(obj) == "function" then
        return function(...)
            local fname = functions[obj]
            if results[fname] == nil then
                results[fname] = {}
                results[fname]["Lua_Remote"] = {} 
                results[fname]["SGX_Local"]  = {} 
                results[fname]["SGX_Remote"] = {} 
            end
            res = offload(fname, ...)
            return res
        end
    elseif type(obj) == "table" then
        for k,v in pairs(obj) do
            functions[v] = k
            obj[k] = wrapper(v)
        end 
    end
    return obj
end

res = loadfile(lua_code)()

