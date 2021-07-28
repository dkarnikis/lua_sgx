--plain = ('a'):rep(10 * 1024 *1024)
local xtea = require "xtea"
iv8 = ('a'):rep(8)
k16 = ('k'):rep(16)
xtea.encrypt(k16, iv8, plain)
