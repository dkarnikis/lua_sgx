--local plain = ('a'):rep(size)
local sha2 = require "sha2"
local bin = require  "bin"  -- for hex conversion
sha2.sha256(plain)
