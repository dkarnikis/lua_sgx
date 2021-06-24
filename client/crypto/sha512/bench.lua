local sha2 = require "sha2"
local bin = require  "bin"
local open = io.open
local function read_file(path)
    local file = open(path, "rb")
    local content = file:read "*a"
    io.close(file)
    return content
end
local data = read_file("out");
sha2.sha512(data)
