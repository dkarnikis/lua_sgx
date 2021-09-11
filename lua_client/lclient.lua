local lclient = {}
package.path = package.path .. ";../libs/?.lua"
utils = require("utils")
client = require('liblclient')
dkjson = require("dkjson")
utils.boot(client)
lclient.mode = 0
tags = {}
task_counter = 0
lua_code = 0
lclient.module_file_name = nil
tags = {}
results = {}
functions = {}
current_tag = ''
lclient.config = 0

lclient.set_module_file = function(mod_f)
    lclient.module_file_name = mod_f
end

lclient.get_module_file = function()
    return lclient.module_file_name
end

lclient.set_mode = function(m)
    lclient.mode = m
end

lclient.get_mode = function(m)
    return lclient.mode
end

lclient.set_config = function(c)
    lclient.config = c
end

lclient.get_config = function()
    return lclient.config
end

lclient.get_tag = function(m)
    return tags[m]
end

lclient.set_current_tag = function(t)
    current_tag = t
end

lclient.get_current_tag = function()
    return current_tag
end

lclient.bootstrap = function()
    tags[0] = "Lua_Remote"
    tags[1] = "SGX_Remote"
    tags[2] = "SGX_Local" 
    --current_tag = tags[mode]
    task_counter = 0
    lua_code = nil

    if _VERSION == "Lua 5.1" or arg == nil then
        local f_config = utils.read_file('sconfig')[1]
        local func = string.gmatch(f_config, '([^,]+)')
        lua_code = func()
        lclient.set_mode(tonumber(func()))
    else
        -- load  the libraries
        lua_code = arg[1]
    end
end

lclient.send_modules = function(worker)
    local module_file_name = lclient.get_module_file()
    -- if we did not supply an input, don't send anything
    if module_file_name == nil then
        client.lsend_module(worker.socket);
    elseif worker.aes_key == nil then
        -- we have an input, but we are not using encryption
        client.lsend_module(worker.socket, module_file_name); 
    else
        -- we have input and we use encryption
        client.lsend_module(worker.socket, module_file_name, worker.aes_key); 
    end
end

lclient.connect_to_worker = function(m)
    lclient.set_mode(m)
    lclient.set_config(utils.lines_from("config", m))

end

lclient.close_worker = function(sock)
    client.lclose_socket(sock)
end

lclient.pick_worker = function() 
    task_counter = task_counter + 1
    return (task_counter % remote_servers) + 1
end

local function pack(...)
    -- Returns a new table with parameters stored into an array, with field "n" being the total number of parameters
    local t = {...}
    t.n = #t
    return t
end

local function offload (...)
    local res = ''
    local mode = lclient.get_mode()
    local args = pack(...)
    local json = dkjson.encode(args, { indent = true})
    json = 'json = [[\n' .. json .. '\n]]'
    --local worker = pick_worker()
    --local spawn_worker = remote_worker()
    local item = lclient.get_config()[1]
    -- remote 'local lua'
    if mode == 0 then
        client.lsend_code(item.socket, json);
        res = client.lrecv_response(item.socket);
        -- remote 'e2e encrypted sgx'
    elseif mode == 1 then
        client.lsend_code(item.socket, json, item.aes_key);
        res = client.lrecv_response(item.socket, item.aes_key);
        -- remote 'local sgx'
    elseif mode == 2 then
        client.lsend_code(item.socket, json);
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
    lclient.set_current_tag(tags[lclient.get_mode()])
    table.insert(results[fname][lclient.get_current_tag()], obj)
    return res
end

lclient.wrapper = function(obj, lib_name)
    if type(obj) == "function" then
        return function(...)
            local fname = lib_name .. '.' .. functions[obj]
            if results[fname] == nil then
                results[fname] = {}
                results[fname]["Lua_Remote"] = {} 
                results[fname]["SGX_Local"]  = {} 
                results[fname]["SGX_Remote"] = {} 
            end
            local res = offload(lib_name, functions[obj], ...)
            return res
        end
    elseif type(obj) == "table" then
        local lib_name = nil
        for k,v in pairs(_G) do
            if v == obj then
                lib_name = k
            end
        end
        for k,v in pairs(obj) do
            functions[v] = k
            obj[k] = lclient.wrapper(v, lib_name)
        end 
    end
    return obj
end

lclient.run_code = function()
    local res = loadfile(lua_code)()
end

return lclient
