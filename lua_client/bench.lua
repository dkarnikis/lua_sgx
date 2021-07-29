package.path = package.path .. ";../libs/?.lua"
package.path = package.path .. ";../libs/crypto/?.lua"
package.path = package.path .. ";../libs/heavy/?.lua"
package.path = package.path .. ";../libs/medium/?.lua"
package.path = package.path .. ";../libs/light/?.lua"
package.path = package.path .. ";../libs/opti/?.lua"
default_loops = 10
local loops = default_loops
-- the module name we are going to offload
local module_file_name = nil
function load_libs() 
    -- first load the libraries in the _G
    -- heavy 
    binarytrees     = require("binarytrees")
    havlak          = require("havlak")
    recursive_fib   = require("recursive_fib")
    nbody           = require("nbody")
    -- medium 
    cd              = require("cd")
    fasta           = require("fasta")
    ray             = require("ray")
    richards        = require("richards")
    -- light
    deltablue       = require("deltablue")
    life            = require("life")
    mandelbrot      = require("mandelbrot")
    queens          = require("queens")
    -- crypto
    blake2b         = require("blake2b")
    chacha20        = require("chacha20")
    checksum        = require("checksum")
    md5             = require("md5")
    norx            = require("norx")
    norx32          = require("norx32")
    rabbit          = require("rabbit")
    rc4             = require("rc4")
    salsa20         = require("salsa20")
    sha2            = require("sha2")
    xtea            = require("xtea")
    -- opts
    opt             = require("opt")
    -- after they have been loaded, we wrap them
    binarytrees     = wrapper(binarytrees)
    havlak          = wrapper(havlak)
    recursive_fib   = wrapper(recursive_fib)
    nbdoy           = wrapper(nbody)

    cd              = wrapper(cd)
    fasta           = wrapper(fasta)
    ray             = wrapper(ray)
    richards        = wrapper(richards)

    deltablue       = wrapper(deltablue)
    life            = wrapper(life)
    mandelbrot      = wrapper(mandelbrot)
    queens          = wrapper(queens)
    -- crypto 
    blake2b         = wrapper(blake2b)
    chacha20        = wrapper(chacha20)
    checksum        = wrapper(checksum)
    md5             = wrapper(md5)
    norx            = wrapper(norx)
    norx32          = wrapper(norx32)
    rabbit          = wrapper(rabbit)
    rc4             = wrapper(rc4)
    salsa20         = wrapper(salsa20)
    sha2            = wrapper(sha2)
    xtea            = wrapper(xtea)
    -- opts
    opt             = wrapper(opt)
    
end

function send_modules(wrk)
    -- if we did not supply an input, don't send anything
    if module_file_name == nil then
        client.lsend_module(wrk.socket);
    elseif wrk.aes_key == nil then
    -- we have an input, but we are not using encryption
        client.lsend_module(wrk.socket, module_file_name); 
    else
    -- we have input and we use encryption
        client.lsend_module(wrk.socket, module_file_name, wrk.aes_key); 
    end
end

function do_bench(func, lib_func, func_name, m, data)
    connect_to_worker(m)
    local wrk = config[1]
    send_modules(wrk)
    current_tag = tags[m]
    print("Doing:", lib_func, current_tag)
    for i = 1,loops, 1 do
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
   -- 
    --print('Bench          ', func_name)
    --print('Lua_Local      ', lua_rem.exec)
    --print('SGX_Local_E2E  ', sgx_local.e2e)
    --print('SGX_Local_INIT ', sgx_local.init)
    --print('SGX_Local_EXEC ', sgx_local.exec)
    --print('LUA_REMOTE_E2E ', lua_rem.e2e)
    --print('LUA_REMOTE_NW  ', lua_rem.nw)
    --print('LUA_REMOTE_INIT', lua_rem.init)
    --print('LUA_REMOTE_EXEC', lua_rem.exec)
    --print('SGX_REMOTE_E2E ', sgx_rem.e2e)
    --print('SGX_REMOTE_NW  ', sgx_rem.nw)
    --print('SGX_REMOTE_INIT', sgx_rem.init)
    --print('SGX_REMOTE_EXEC', sgx_rem.exec)
end

function do_heavy(arg)
    do_remote(havlak.run_iter, 'havlak.run_iter', 'havlak', arg)
    do_remote(nbody.run_iter, 'nbody.run_iter', 'nbody', arg)
    do_remote(recursive_fib.run_iter, 'recursive_fib.run_iter', 'fib', arg)
    do_remote(binarytrees.run_iter, 'binarytrees.run_iter', 'binarytrees', arg)
end

function do_light(arg)
    do_remote(deltablue.run_iter, 'deltablue.run_iter', 'deltablue', arg)
    do_remote(life.run_iter, 'life.run_iter', 'life', arg)
    do_remote(mandelbrot.run_iter, 'mandelbrot.run_iter', 'mandelbrot', arg)
    do_remote(queens.run_iter, 'queens.run_iter', 'queens', arg)
end

function do_medium(arg)
    do_remote(cd.run_iter, 'cd.run_iter', 'collisiondetection', arg)
    do_remote(fasta.run_iter, 'fasta.run_iter', 'fasta', arg)
    do_remote(ray.run_iter, 'ray.run_iter', 'ray', arg)
    do_remote(richards.run_iter, 'richards.run_iter', 'richards', arg)
end



load_libs()
function do_algo()
    do_light(100)
    do_medium(100)
    do_heavy(40)
end

function do_crypto(data)
    do_remote(blake2b.hash, 'blake2b.hash', 'blake2b', data)
    do_remote(chacha20.run, 'chacha20.run', 'chacha20', data)
    do_remote(checksum.crc32, 'checksum.crc32', 'checksum', data)
    do_remote(md5.hash, 'md5.hash', 'md5', data)
    do_remote(norx.run, 'norx.run', 'norx', data)
    do_remote(norx32.run, 'norx32.run', 'norx32', data)
    do_remote(rabbit.run, 'rabbit.run', 'rabbit', data)
    do_remote(rc4.run, 'rc4.run', 'rc4', data)
    do_remote(salsa20.run, 'salsa20.run', 'salsa20', data)
    do_remote(sha2.sha256, 'sha2.sha256', 'sha256', data)
    do_remote(sha2.sha512, 'sha2.sha512', 'sha512', data)
    do_remote(xtea.run, 'xtea.run', 'xtea', data)
end

function do_touches()
    local lim = 1024 * 1024 * 4
    local i = 1024
    while i <= lim do
        do_remote(opt.reads, 'opt.reads', 'reads', i)
        do_remote(opt.writes, 'opt.writes', 'writes', i)
        i = i * 2
    end
end

-- start printing from 10K to 1M
function do_prints()
    local lim = 1000000
    local i = 10000
    while i <= lim do
        do_remote(opt.t_print, 'opt.t_print', 'print', i)
        if i == 10000 then
            i = i * 10
        else
            i = i + 100000
        end
    end
end

-- start printing from 10K to 1M
function do_freads()
    local lim = 4 * 1024 * 1024
    local i = 1024
    module_file_name = 'out'
    local file = io.open ('out', 'w')
    local data = string.rep('x', 32 * 1024 * 1024) .. 'a' -- * 1024 * 1024)..'a'
    file:write(data)
    io.close(file)
    while i <= lim do
        print(i)
        do_remote(opt.fread, 'opt.fread', 'fread', i)
        i = i * 2
    end
    module_file_name = nil
end

local data = string.rep('x', 1000000)
--do_remote(sha2.sha256, 'sha2.sha256', 'sha256', data)
-- completed
do_algo()
do_crypto(data)
do_touches()
do_prints()
do_freads()
