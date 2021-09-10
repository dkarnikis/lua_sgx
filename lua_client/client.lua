package.path = package.path .. ";../libs/?.lua"
client = require('liblclient')
utils = require("utils")
dkjson = require("dkjson")

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

local module_file_name = nil
mode = 1
config = nil
functions = {}
results = {}
tags = {}
tags[0] = "Lua_Remote"
tags[1] = "SGX_Remote"
tags[2] = "SGX_Local" 
current_tag = tags[mode]
local task_counter = 0
lua_code = nil

if _VERSION == "Lua 5.1" or arg == nil then
    local f_config = utils.read_file('sconfig')[1]
    local func = string.gmatch(f_config, '([^,]+)')
    lua_code = func()
    mode = tonumber(func())
else
    -- load  the libraries
    lua_code = arg[1]
end
if lua_code == nil then
    print("Give a lua code")
    os.exit(1)
end

function send_modules(worker)
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

function connect_to_worker(m)
    mode = m
    config = utils.lines_from("config", mode)
end

function close_worker(sock)
    client.lclose_socket(sock)
end


local function pick_worker() 
    task_counter = task_counter + 1
    return (task_counter % remote_servers) + 1
end

function pack(...)
    -- Returns a new table with parameters stored into an array, with field "n" being the total number of parameters
    local t = {...}
    t.n = #t
    return t
end

local function offload (...)
    local args = pack(...)
    local json = dkjson.encode(args, { indent = true})
    json = 'json = [[\n' .. json .. '\n]]'
    --local worker = pick_worker()
    --local spawn_worker = remote_worker()
    local item = config[1]
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
        local lib_name = nil
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
if lua_code ~= nil then
    local res = loadfile(lua_code)()
end
