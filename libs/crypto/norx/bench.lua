--plain = ('a'):rep(10 * 1024 *1024) 
local norx = require "norx"
local k = ('k'):rep(32)  -- key
local n = ('n'):rep(32)  -- nonce
local a = ('a'):rep(16)  -- header ad  (61 61 ...)
local z = ('z'):rep(8)   -- trailer ad  (7a 7a ...)
norx.aead_encrypt(k, n, plain, a, z)
