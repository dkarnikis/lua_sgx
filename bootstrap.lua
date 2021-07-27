-- see if the file exists
function file_exists(file)
    local f = io.open(file, "rb")
    if f then f:close() end
    return f ~= nil
end

-- get all lines from a file, returns an empty 
-- list/table if the file does not exist
function lines_from(file)
    if not file_exists(file) then return {} end
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
    local command = v .. " = require('libs/" .. v .. "');"
    load(command)()
    -- push it to the global scope 
    for k1,v1 in pairs(_G[v]) do
        _G[k] = v
    end
end

