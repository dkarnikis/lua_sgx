-- Copyright (c) 2015  Phil Leblanc  -- see LICENSE file

------------------------------------------------------------
-- sha2 tests

local sha2 = require "sha2"
local bin = require  "bin"  -- for hex conversion
local open = io.open

local function read_file(path)
    local file = open(path, "rb") -- r read mode and b binary mode
    local content = file:read "*a" -- *a or *all reads the whole file
    return content
end

local data = read_file("out");
sha2.sha512(data)
