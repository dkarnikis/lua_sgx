package.path = package.path .. ";../libs/?.lua"
package.path = package.path .. ";../libs/crypto/?.lua"
package.path = package.path .. ";../libs/heavy/?.lua"
package.path = package.path .. ";../libs/medium/?.lua"
package.path = package.path .. ";../libs/light/?.lua"
package.path = package.path .. ";../libs/opti/?.lua"
os.execute("rm -rf results; mkdir results");


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
    --sha2            = wrapper(sha2)
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

-- 100k bytes array xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
local data = string.rep('x', 100)
-- completed
--do_algo()
--do_crypto(data)
-- An den exw kanei connect ston server, kane connect
if config == nil then
    -- to mode einai mia global pou pairnei 3 times, 0, 1,2
    -- 0 = Remote Vanilla Lua Interpreter
    -- 1 = Remote SGX LuaVM E2E encryption
    -- 2 = Remote SGX LuaVM Xwris encryption
    connect_to_worker(mode)
end

load_libs()
---- dialegw to prwti entry tou remote worker
local wrk = config[1]
-- stelnw ta modules 
send_modules(wrk)
-- kanw wrap to critical function
sha2 = wrapper(sha2)
res = sha2.sha256(data)
print(res)
