local sha2 = require("sha2")
local bin = require("bin")
local utils = require("utils")

sha2 = wrapper(sha2)
config = 0

function do_bench(func, func_name, tag, m, data)
    mode = m
    current_tag = tag
    config = utils.lines_from("config", mode)
    for i = 1,10, 1 do
        func(data)
    end
    client.lclose_socket(config[1].socket)
    return get_avg_time(func_name, tag)
end

function get_avg_time(func_name, tag) 
    local e2e = 0
    local exec = 0
    local init = 0
    local nw = 0
    local array = results[func_name][tag]
    for k,v in ipairs(array) do
        e2e  = e2e + v.e2e
        nw   = nw + v.nw
        init = init + v.init
        exec = exec + v.exec
    end
    local len = #array
    array = { e2e = e2e / len, nw = nw / len, init = init / len, exec = exec / len}
    return array
end
function do_remote(func, func_name, ...)
    local lua_rem = do_bench(func, func_name, "Lua_Remote", 0, ...)
    local sgx_rem = do_bench(func, func_name, "SGX_Remote", 1, ...)
    local sgx_local = do_bench(func, func_name, "SGX_Local",  2, ...)
    print('Bench\tLua_Local\tSGX_Local_E2E\tSGX_Local_INIT\tSGX_LOCAL_EXEC\tLUA_R_E2E\tLUA_R_NW\tLUA_R_INIT\tLUA_R_EXEC\tSGX_R_E2E\tSGX_R_NW\tSGX_R_INIT\tSGX_R_EXEC')
    print(func_name, lua_rem.exec, sgx_local.e2e, sgx_local.init, sgx_local.exec, lua_rem.e2e, lua_rem.nw, lua_rem.init, lua_rem.exec,
        sgx_rem.e2e, sgx_rem.nw, sgx_rem.init, sgx_rem.exec)
end

local data = string.rep('x', 1000000)

do_remote(sha2.sha256, 'sha256', data)

