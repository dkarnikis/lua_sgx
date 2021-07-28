local morus = require "morus"
local k = ('k'):rep(16)  -- key
local n = ('n'):rep(16)  -- nonce
local a = ('a'):rep(16)  -- ad  (61 61 ...)
--local m = ('m'):rep(sizemb * 1024 * 1024)
local c = morus.encrypt(k, n, plain)
