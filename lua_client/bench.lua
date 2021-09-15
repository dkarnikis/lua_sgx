package.path = package.path .. ";../libs/?.lua"
package.path = package.path .. ";../libs/crypto/?.lua"
package.path = package.path .. ";../libs/heavy/?.lua"
package.path = package.path .. ";../libs/medium/?.lua"
package.path = package.path .. ";../libs/light/?.lua"
package.path = package.path .. ";../libs/opti/?.lua"
package.path = package.path .. ";../libs/macro/snabb/?.lua"
os.execute("rm -rf results; mkdir results");
lua_client = require("lclient")
lua_client.bootstrap()

default_loops = 2
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
    vpn             = require("vpn")
    -- after they have been loaded, we wrap them
    vpn             = lua_client.wrapper(vpn)
    binarytrees     = lua_client.wrapper(binarytrees)
    havlak          = lua_client.wrapper(havlak)
    recursive_fib   = lua_client.wrapper(recursive_fib)
    nbdoy           = lua_client.wrapper(nbody)

    cd              = lua_client.wrapper(cd)
    fasta           = lua_client.wrapper(fasta)
    ray             = lua_client.wrapper(ray)
    richards        = lua_client.wrapper(richards)

    deltablue       = lua_client.wrapper(deltablue)
    life            = lua_client.wrapper(life)
    mandelbrot      = lua_client.wrapper(mandelbrot)
    queens          = lua_client.wrapper(queens)
    -- crypto 
    blake2b         = lua_client.wrapper(blake2b)
    chacha20        = lua_client.wrapper(chacha20)
    checksum        = lua_client.wrapper(checksum)
    md5             = lua_client.wrapper(md5)
    norx            = lua_client.wrapper(norx)
    norx32          = lua_client.wrapper(norx32)
    rabbit          = lua_client.wrapper(rabbit)
    rc4             = lua_client.wrapper(rc4)
    salsa20         = lua_client.wrapper(salsa20)
    sha2            = lua_client.wrapper(sha2)
    xtea            = lua_client.wrapper(xtea)
    -- opts
    opt             = lua_client.wrapper(opt)
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
    lua_client.set_mode(m)
    lua_client.connect_to_worker(m)
    local wrk = lua_client.get_config()[1]
    send_modules(wrk)
    print("Doing:", lib_func, lua_client.get_current_tag())
    for i = 1,loops, 1 do
        print(func(data))
    end
    lua_client.close_worker(wrk.socket)
    return get_avg_time(lib_func)
end

function get_avg_time(func_name) 
    local e2e = 0
    local exec = 0
    local init = 0
    local nw = 0
    local tag = lua_client.get_current_tag()
    local array = lua_client.results[func_name][tag]
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
    lua_client.results = {}
    lua_client.results.func_name = func_name
    lua_client.results.lua_rem = lua_rem
    lua_client.results.sgx_rem = sgx_rem
    lua_client.results.sgx_local = sgx_local
    return lua_client.results
end

function do_heavy(arg)
    local r1 = do_remote(havlak.run_iter, 'havlak.run_iter', 'havlak', arg)
    local r2 = do_remote(nbody.run_iter, 'nbody.run_iter', 'nbody', arg)
    local r3 = do_remote(recursive_fib.run_iter, 'recursive_fib.run_iter', 'fib', arg)
    local r4 = do_remote(binarytrees.run_iter, 'binarytrees.run_iter', 'binarytrees', arg)
    local file = io.open ('results/heavy', 'w')
    -- switch stdout to our file
    io.output(file)
    io.write('#Bench Lua_Local SGX_Local_E2E SGX_Local_INIT SGX_LOCAL_EXEC LUA_R_E2E LUA_R_NW LUA_R_INIT LUA_R_EXEC SGX_R_E2E SGX_R_NW SGX_R_INIT SGX_R_EXEC\n')
    print_all(r1)
    print_all(r2)
    print_all(r3)
    print_all(r4)
    io.close(file)
    os.execute("cat results/heavy | column -t > a; mv a results/heavy;");
end

function print_all(r)
    io.write(r.func_name,' ', r.lua_rem.exec,' ', r.sgx_local.e2e,' ', r.sgx_local.init, 
    ' ', r.sgx_local.exec,' ', r.lua_rem.e2e, ' ', r.lua_rem.nw, ' ', r.lua_rem.init, 
    ' ', r.lua_rem.exec, ' ', r.sgx_rem.e2e, ' ', r.sgx_rem.nw, ' ', r.sgx_rem.init, 
    ' ', r.sgx_rem.exec,'\n')
end

function do_light(arg)
    local r1 = do_remote(deltablue.run_iter, 'deltablue.run_iter', 'deltablue', arg)
    local r2 = do_remote(life.run_iter, 'life.run_iter', 'life     ', arg)
    local r3 = do_remote(mandelbrot.run_iter, 'mandelbrot.run_iter', 'mandelbrot', arg)
    local r4 = do_remote(queens.run_iter, 'queens.run_iter', 'queens    ', arg)
    local file = io.open ('results/light', 'w')
    -- switch stdout to our file
    io.output(file)
    io.write('#Bench Lua_Local SGX_Local_E2E SGX_Local_INIT SGX_LOCAL_EXEC LUA_R_E2E LUA_R_NW LUA_R_INIT LUA_R_EXEC SGX_R_E2E SGX_R_NW SGX_R_INIT SGX_R_EXEC\n')
    print_all(r1)
    print_all(r2)
    print_all(r3)
    print_all(r4)
    io.close(file)
    os.execute("cat results/light | column -t > a; mv a results/light;");
end

function do_medium(arg)
    local r1 = do_remote(cd.run_iter, 'cd.run_iter', 'collisiondetection', arg)
    local r2 = do_remote(fasta.run_iter, 'fasta.run_iter', 'fasta', arg)
    local r3 = do_remote(ray.run_iter, 'ray.run_iter', 'ray', arg)
    local r4 = do_remote(richards.run_iter, 'richards.run_iter', 'richards', arg)
    local file = io.open ('results/medium', 'w')
    -- switch stdout to our file
    io.output(file)
    io.write('#Bench Lua_Local SGX_Local_E2E SGX_Local_INIT SGX_LOCAL_EXEC LUA_R_E2E LUA_R_NW LUA_R_INIT LUA_R_EXEC SGX_R_E2E SGX_R_NW SGX_R_INIT SGX_R_EXEC\n')
    print_all(r1)
    print_all(r2)
    print_all(r3)
    print_all(r4)
    io.close(file)
    os.execute("cat results/medium | column -t > a; mv a results/medium;");
end

function copy_config(c)
    os.execute("cp ../configs/" .. c .." ../lib_config")
end

load_libs()
function do_algo()
    copy_config("light_config")
    do_light(100)
    copy_config("medium_config")
    do_medium(40)
    copy_config("heavy_config")
    do_heavy(40)
end

function do_crypto(data)
    os.execute("cp ../configs/crypto_config ../lib_config")
    local r1 = do_remote(blake2b.hash, 'blake2b.hash', 'blake2b', data)
    local r2 = do_remote(chacha20.run, 'chacha20.run', 'chacha20', data)
    local r3 = do_remote(checksum.crc32, 'checksum.crc32', 'checksum', data)
    local r4 = do_remote(md5.hash, 'md5.hash', 'md5', data)
    local r5 = do_remote(norx.run, 'norx.run', 'norx', data)
    local r6 = do_remote(norx32.run, 'norx32.run', 'norx32', data)
    local r7 = do_remote(rabbit.run, 'rabbit.run', 'rabbit', data)
    local r8 = do_remote(rc4.run, 'rc4.run', 'rc4', data)
    local r9 = do_remote(salsa20.run, 'salsa20.run', 'salsa20', data)
    local r10 = do_remote(sha2.sha256, 'sha2.sha256', 'sha256', data)
    local r11 = do_remote(sha2.sha512, 'sha2.sha512', 'sha512', data)
    local r12 = do_remote(xtea.run, 'xtea.run', 'xtea', data)
    local file = io.open ('results/crypto', 'w')
    -- switch stdout to our file
    io.output(file)
    io.write('#Bench Lua_Local SGX_Local_E2E SGX_Local_INIT SGX_LOCAL_EXEC LUA_R_E2E LUA_R_NW LUA_R_INIT LUA_R_EXEC SGX_R_E2E SGX_R_NW SGX_R_INIT SGX_R_EXEC\n')
    print_all(r1)
    print_all(r2)
    print_all(r3)
    print_all(r4)
    print_all(r5)
    print_all(r6)
    print_all(r7)
    print_all(r8)
    print_all(r9)
    print_all(r10)
    print_all(r11)
    print_all(r12)
    io.close(file)
    os.execute("cat results/crypto | column -t > a; mv a results/crypto;");

end

function do_touches()
    do_reads()
    do_writes()
end

function do_reads()
    local lim = 1024 * 1024 * 4
    local i = 1024
    file = io.open("results/reads", "w")
    io.output(file)
    io.write('#Array_Size Lua_Local SGX_Local_E2E SGX_Local_INIT SGX_LOCAL_EXEC LUA_R_E2E LUA_R_NW LUA_R_INIT LUA_R_EXEC SGX_R_E2E SGX_R_NW SGX_R_INIT SGX_R_EXEC\n')
    while i <= lim do
        local r = do_remote(opt.reads, 'opt.reads', 'reads', i)
        r.func_name = i
        print_all(r)
        i = i * 2
    end
    io.close(file)
    os.execute("cat results/reads | column -t > a; mv a results/reads;");
end

function do_writes()
    local lim = 1024 * 1024 * 4
    local i = 1024
    file = io.open("results/writes", "w")
    io.output(file)
    io.write('#Array_Size Lua_Local SGX_Local_E2E SGX_Local_INIT SGX_LOCAL_EXEC LUA_R_E2E LUA_R_NW LUA_R_INIT LUA_R_EXEC SGX_R_E2E SGX_R_NW SGX_R_INIT SGX_R_EXEC\n')
    while i <= lim do
        local r = do_remote(opt.writes, 'opt.writes', 'writes', i)
        r.func_name = i
        print_all(r)
        i = i * 2
    end
    io.close(file)
    os.execute("cat results/writes | column -t > a; mv a results/writes;");
end

-- start printing from 10K to 1M
function do_prints()
    local lim = 1000000
    local i = 10000
    file = io.open("results/prints", "w")
    io.output(file)
    io.write('#Print_NUM Lua_Local SGX_Local_E2E SGX_Local_INIT SGX_LOCAL_EXEC LUA_R_E2E LUA_R_NW LUA_R_INIT LUA_R_EXEC SGX_R_E2E SGX_R_NW SGX_R_INIT SGX_R_EXEC\n')
    while i <= lim do
        local r = do_remote(opt.t_print, 'opt.t_print', 'print', i)
        r.func_name = i
        print_all(r)
        if i == 10000 then
            i = i * 10
        else
            i = i + 100000
        end
    end
    io.close(file)
    os.execute("cat results/prints | column -t > a; mv a results/prints;");
end

-- start printing from 10K to 1M
function do_freads()
    local lim = 4 * 1024 * 1024
    local i = 64
    module_file_name = 'out'
    local file = io.open ('out', 'w')
    local data = string.rep('x', 32 * 1024 * 1024) .. 'a' -- * 1024 * 1024)..'a'
    file:write(data)
    io.close(file)
    file = io.open("results/fread", "w")
    io.output(file)
    io.write('#Print_NUM Lua_Local SGX_Local_E2E SGX_Local_INIT SGX_LOCAL_EXEC LUA_R_E2E LUA_R_NW LUA_R_INIT LUA_R_EXEC SGX_R_E2E SGX_R_NW SGX_R_INIT SGX_R_EXEC\n')
    while i <= lim do
        local r = do_remote(opt.fread, 'opt.fread', 'fread', i)
        r.func_name = i
        print_all(r)
        i = i * 2
    end
    module_file_name = nil
    io.close(file)
    os.execute("cat results/fread | column -t > a; mv a results/fread;");
end

local data = string.rep('x', 1)
-- completed
do_algo()
--do_crypto(data)
--do_touches()
--do_prints()
--do_freads()
--connect_to_worker(mode)
--local wrk = config[1]
--send_modules(wrk)
--print(test_print.my_print("lala"))
