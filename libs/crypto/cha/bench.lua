--lain = ('a'):rep(10 * 1024 *1024) 
local cha = require "chacha20"
counter = 1
nonce = ('n'):rep(12)
k32 = ('k'):rep(32)
cha.encrypt(k32, counter, nonce, plain)
