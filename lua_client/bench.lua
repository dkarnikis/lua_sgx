package.path = package.path .. ";../libs/?.lua"
sha2 = require("sha2")
cd = require("cd")
bin = require("bin")
utils = require("utils")
cd = wrapper(cd)
sha2 = wrapper(sha2)
config = 0

function do_bench(func, lib_func, func_name, tag, m, data)
    mode = m
    current_tag = tag
    config = utils.lines_from("config", mode)
    for i = 1,10, 1 do
        func(data)
    end
    client.lclose_socket(config[1].socket)
    return get_avg_time(lib_func, tag)
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
function do_remote(func_ptr, lib_func, func_name, ...)
    local lua_rem = do_bench(func_ptr, lib_func, func_name, "Lua_Remote", 0, ...)
    local sgx_rem = do_bench(func_ptr, lib_func, func_name, "SGX_Remote", 1, ...)
    local sgx_local = do_bench(func_ptr, lib_func, func_name, "SGX_Local",  2, ...)
    print('Bench Lua_Local SGX_Local_E2E SGX_Local_INIT SGX_LOCAL_EXEC LUA_R_E2E LUA_R_NW LUA_R_INIT LUA_R_EXEC SGX_R_E2E SGX_R_NW SGX_R_INIT SGX_R_EXEC')
    print(func_name, lua_rem.exec, sgx_local.e2e, sgx_local.init, sgx_local.exec, lua_rem.e2e, lua_rem.nw, lua_rem.init, lua_rem.exec,
        sgx_rem.e2e, sgx_rem.nw, sgx_rem.init, sgx_rem.exec)
end

local data = string.rep('x', 10000)
--do_remote(sha2.sha256, 'sha.sha256', 'sha256', data)
do_remote(cd.run_iter, 'cd.run_iter', 'collisiondetection', 40)
