--lain = ('a'):rep(10 * 1024 *1024) 
local chk = require "checksum"
k32 = ('k'):rep(32)
local et, h  -- encrypted text, hash/hmac
h = chk.adler32(plain)
h = chk.crc32(plain)
h = chk.crc32_nt(plain)
