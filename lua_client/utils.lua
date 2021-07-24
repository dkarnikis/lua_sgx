local utils = {}
client = require('foo')
-- see if the file exists
function file_exists(file)
    local f = io.open(file, "rb")
    if f then f:close() end
    return f ~= nil
end

-- get all lines from a file, returns an empty 
-- list/table if the file does not exist
function utils.lines_from(file, mode)
    if not file_exists(file) then return {} end
    lines = {}
    for line in io.lines(file) do 
        local func = string.gmatch(line, '([^,]+)')
        local server = func()
        local port = func()
        local sock = client.lconnect(server, port, mode)
        -- we have encryption
        if mode == "1" then
            local aes_key = client.lhandshake(sock)
            lines[#lines + 1] = 
            {
                server = server, 
                port = port, 
                aes_key = aes_key, 
                socket = sock
            };
        else
            lines[#lines + 1] = 
            {
                server = server, 
                port = port, 
                socket = sock
            };
        end
    end
    return lines
end
return utils
