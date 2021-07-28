local ec25519 = require "ec25519"
local base = ec25519.base
k32=('k'):rep(32)
for i = 1, 100 do et = ec25519.scalarmult(k32, base) end
