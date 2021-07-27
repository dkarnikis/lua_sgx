local client = require('foo')
package.path = package.path .. ";../libs/?.lua"
dkjson = require("dkjson")
-- load  the libraries

lua_code = arg[1]
mode = 1 --tonumber(arg[2])
functions = {}
results = {}
current_tag = nil
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
    local fname = args[1] .. '.' .. args[2]
    table.insert(results[fname][current_tag], obj)
    return res
end

function wrapper (obj, lib_name)
    if type(obj) == "function" then
        return function(...)
            local fname = lib_name .. '.' ..functions[obj]
            if results[fname] == nil then
                results[fname] = {}
                results[fname]["Lua_Remote"] = {} 
                results[fname]["SGX_Local"]  = {} 
                results[fname]["SGX_Remote"] = {} 
            end
            res = offload(lib_name, functions[obj], ...)
            return res
        end
    elseif type(obj) == "table" then
        local lib_name = 0
        for k,v in pairs(_G) do
            if v == obj then
                lib_name = k
            end
        end
        for k,v in pairs(obj) do
            functions[v] = k
            obj[k] = wrapper(v, lib_name)
        end 
    end
    return obj
end

res = loadfile(lua_code)()

