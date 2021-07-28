--plain = ('a'):rep(10 * 1024 *1024)
local rc4 = require "rc4"
k16 = ('k'):rep(16)
rc4.rc4raw(k16, plain)
