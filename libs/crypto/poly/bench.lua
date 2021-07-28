--plain = ('a'):rep(10 * 1024 *1024)
local poly = require "poly1305"
k32 = ('k'):rep(32)
poly.auth(k32, k32)
