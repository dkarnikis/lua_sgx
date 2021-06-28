lua_code = arg[1]
functions = {}
-- load  the libraries
client = require('foo')
local dkjson = require ("dkjson")
server="127.0.0.1"
port=8000
socket=client.lconnect(server, port)
aes_key = client.lhandshake(socket)

if lua_code == nil then
    print("Give a lua code")
    os.exit(1)
end

local function offload (...)
    local args = table.pack(...)
    --func_name = table.remove(args, 1)
    json = dkjson.encode(args, { indent = true})
    json = 'json = \'' .. json .. '\''
    client.lsend_code(socket, json, aes_key);
    res = client.lrecv_response(socket, aes_key);
    io.write(res)
end

function wrapper (obj)
    if type(obj) == "function" then
        --hooked_functions[obj] = true
        return function(...)
            offload(functions[obj], ...)
            if run_local == true then
                return obj(...)
            end
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

