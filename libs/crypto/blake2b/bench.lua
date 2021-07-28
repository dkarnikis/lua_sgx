--plain = ('a'):rep(10 * 1024 *1024) 
local blake2b = require "blake2b"
blake2b.hash(plain)
