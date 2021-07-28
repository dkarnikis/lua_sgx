--plain = ('a'):rep(10 * 1024 *1024) 
local md5 = require "md5"
local bin = require "bin"
local hash = md5.hash
local d = hash(plain)
