md5 = require ("md5")
hash = md5.hash
local open = io.open
local function read_file(path) 
    local file = open(path, "rb") 
    local content = file:read "*a" 
    return content
end
local data = read_file("out");
local d = hash(data)
print(hash(data))