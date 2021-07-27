package.path = package.path .. ";../libs/?.lua"
sha2 = require("sha2")
cd = require("cd")
bin = require("bin")
binarytrees = require("binarytrees")
binarytrees = wrapper(binarytrees)
havlak = require("havlak")
havlak = wrapper(havlak)
recursive_fib = require("recursive_fib")
recursive_fib = wrapper(recursive_fib)
nbody = require("nbody")
nbody = wrapper(nbody)
cd = wrapper(cd)
sha2 = wrapper(sha2)

function do_bench(func, lib_func, func_name, m, data)
    connect_to_worker(m)
    current_tag = tags[m]
    print(lib_func, current_tag)
    for i = 1,10, 1 do
        func(data)
    end
    close_worker(config[1].socket)
    return get_avg_time(lib_func)
end

function get_avg_time(func_name) 
    local e2e = 0
    local exec = 0
    local init = 0
    local nw = 0
    local tag = tags[mode]
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
    local lua_rem = do_bench(func_ptr, lib_func, func_name, 0, ...)
    local sgx_rem = do_bench(func_ptr, lib_func, func_name, 1, ...)
    local sgx_local = do_bench(func_ptr, lib_func, func_name, 2, ...)
    --print('Bench Lua_Local SGX_Local_E2E SGX_Local_INIT SGX_LOCAL_EXEC LUA_R_E2E LUA_R_NW LUA_R_INIT LUA_R_EXEC SGX_R_E2E SGX_R_NW SGX_R_INIT SGX_R_EXEC')
    --print(func_name, lua_rem.exec, sgx_local.e2e, sgx_local.init, sgx_local.exec, lua_rem.e2e, lua_rem.nw, lua_rem.init, lua_rem.exec,
    --    sgx_rem.e2e, sgx_rem.nw, sgx_rem.init, sgx_rem.exec)
    print('Bench          ', func_name)
    print('Lua_Local      ', lua_rem.exec)
    print('SGX_Local_E2E  ', sgx_local.e2e)
    print('SGX_Local_INIT ', sgx_local.init)
    print('SGX_Local_EXEC ', sgx_local.exec)
    print('LUA_REMOTE_E2E ', lua_rem.e2e)
    print('LUA_REMOTE_NW  ', lua_rem.nw)
    print('LUA_REMOTE_INIT', lua_rem.init)
    print('LUA_REMOTE_EXEC', lua_rem.exec)
    print('SGX_REMOTE_E2E ', sgx_rem.e2e)
    print('SGX_REMOTE_NW  ', sgx_rem.nw)
    print('SGX_REMOTE_INIT', sgx_rem.init)
    print('SGX_REMOTE_EXEC', sgx_rem.exec)

end

local data = string.rep('x', 10000)
--do_remote(sha2.sha256, 'sha2.sha256', 'sha256', data)
do_remote(havlak.run_iter, 'havlak.run_iter', 'havlak', 40)
do_remote(nbody.run_iter, 'nbody.run_iter', 'nbody', 40)
do_remote(recursive_fib.run_iter, 'recursive_fib.run_iter', 'fib', 40)
do_remote(cd.run_iter, 'cd.run_iter', 'collisiondetection', 40)
do_remote(binarytrees.run_iter, 'binarytrees.run_iter', 'binarytrees', 40)
