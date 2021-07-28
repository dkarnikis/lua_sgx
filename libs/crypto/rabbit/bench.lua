--plain = ('a'):rep(10 * 1024 *1024) 
local rabbit = require "rabbit"
k16 = ('k'):rep(16)
iv8 = ('i'):rep(8)
rabbit.encrypt(k16, iv8, plain)
