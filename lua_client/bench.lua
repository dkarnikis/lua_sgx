local sha2 = require("sha2")
local bin = require("bin")
run_local = false
sha2 = wrapper(sha2)
sha2.sha256(string.rep('x', 10000000))
sha2.sha256(string.rep('x', 10))
sha2.sha256(string.rep('x', 10000000))
--file_to_load = 'l.lua'
--loadfile(file_to_load)()
