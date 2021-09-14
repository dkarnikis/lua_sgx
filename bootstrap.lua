package.path = package.path .. ";libs/?.lua"
package.path = package.path .. ";libs/crypto/?.lua"
package.path = package.path .. ";libs/opti/?.lua"
package.path = package.path .. ";libs/medium/?.lua"
package.path = package.path .. ";libs/heavy/?.lua"
package.path = package.path .. ";libs/light/?.lua"
package.path = package.path .. ";libs/macro/snabb/pflua/?.lua"

-- see if the file exists
function file_exists(file)
    local f = io.open(file, "rb")
    if f then f:close() end
    return f ~= nil
end

-- get all lines from a file, returns an empty 
-- list/table if the file does not exist
function lines_from(file)
    if not file_exists(file) then 
        return {} 
    end
    lines = {}
    for line in io.lines(file) do 
        lines[#lines + 1] = line
    end
    return lines
end

function getf_from_lib(lib, f) 
    for k,v in pairs(lib) do
        if k == f then
            return v
        end
    end
    return nil
end

-- tests the functions above
local file = 'lib_config'
local lines = lines_from(file)
-- print all line numbers and their contents
for k,v in pairs(lines) do
    local name, path = v:match("([^:]+):([^:]+)")
    local command = name .. " = require('libs/" .. path .. "');"
    load(command)()
    -- push it to the global scope 
    for k1,v1 in pairs(_G[name]) do
        _G[k] = name
    end
end

function read_file(path)
    local open = io.open
    local file = open(path, "rb") -- r read mode and b binary mode
    if not file then return nil end
    local content = file:read "*a" -- *a or *all reads the whole file
    file:close()
    return content
end
