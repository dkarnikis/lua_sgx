local sha2 = require("sha2")
local bin = require("bin")
run_local = false
sha2 = wrapper(sha2)
for i =0,10,1
do
    sha2.sha256(string.rep('x', 1000000))
end
