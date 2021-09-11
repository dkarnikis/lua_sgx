module(...,package.seeall)

package.path = package.path .. ";../../../libs/?.lua"
package.path = package.path .. ";../../../../libs/?.lua"
package.path = package.path .. ";../../../../../libs/?.lua"
package.path = package.path .. ";../../../../../../libs/?.lua"
package.path = package.path .. ";../../../libs/macro/snabb/?.lua"
package.path = package.path .. ";../../../../libs/macro/snabb/?.lua"
package.path = package.path .. ";../../../../../libs/macro/snabb/?.lua"
local ffi = require("ffi")
local dkjson = require("dkjson")
local app  = require("core.app")
local link = require("core.link")
local packet = require("core.packet")
local pcap = require("lib.pcap.pcap")

client = require('lclient')
client.bootstrap()
client.set_mode(0)
client.connect_to_worker(0)
client.set_module_file(nil)
client.send_modules(client.get_config()[1])

--local json = require("dkjson")
SGXReader = {}
opt = 0
packets = 0
bytes_sent = 0;

_G.vpn = require("vpn")
_G.vpn = client.wrapper(_G.vpn)
function SGXReader:new (filename)
    local records = pcap.records(filename)
    return setmetatable({iterator = records, done = false},
    {__index = SGXReader})
end

function SGXReader:pull ()
    local limit = engine.pull_npackets
    while limit > 0 and not self.done do
        limit = limit - 1
        local data, record, extra = self.iterator()
        if data then
            local p = packet.from_string(data)
            -- print(ffi.string(p.data, p.length))
            link.transmit(self.output.output, p)
        else
            self.done = true
        end
    end
end

SGXWriter = {}

function SGXWriter:new (filename)
    local file = io.open(filename, "w")
    pcap.write_file_header(file)
    return setmetatable({file = file}, {__index = SGXWriter})
end

function write_data_to_file(data, len, f)
    file = io.open(f, "w")
    file:write(opt)
    file:write(ffi.string(data, len))
    file:close()
end

local function read_file(path)
    local file = io.open(path, "r")
    local a = file:read("*a")
    file:close()
    return a
end

local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/' -- You will need this for encoding/decoding
-- encoding
function enc(data)
    return ((data:gsub('.', function(x) 
        local r,b='',x:byte()
        for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
        return r;
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c=0
        for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
        return b:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#data%3+1])
end


-- decoding
function dec(data)
    data = string.gsub(data, '[^'..b..'=]', '')
    return (data:gsub('.', function(x)
        if (x == '=') then return '' end
        local r,f='',(b:find(x)-1)
        for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
        return r;
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if (#x ~= 8) then return '' end
        local c=0
        for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
            return string.char(c)
    end))
end

function sgx_encrypt(data, len)
	-- generate the string
    local d2s = ffi.string(data, len)
    to_send = {}
	-- send the mode for crypto / 1 = encrypt, 0 decrypt
    to_send.mode = opt
	-- encode with base64 so we avoid weird characters on json
    to_send.data = enc(d2s)
	-- remote offloading
    local res = vpn.exec(to_send)
	-- base64 decrypt the date
    return dec(res)
end

function SGXWriter:push ()
    while not link.empty(self.input.input) do
        local p = link.receive(self.input.input)
        pcap.write_record_header(self.file, p.length)
        -- do the remote offloading 
        local d = sgx_encrypt(p.data, p.length)
        -- we have the results
        bytes_sent = 1 + bytes_sent + p.length
        packets = packets + 1
		-- write the payload to the file
        self.file:write(d) 
        self.file:flush()
        packet.free(p)
    end
end
