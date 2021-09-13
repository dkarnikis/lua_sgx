module(...,package.seeall)

package.path = package.path .. ";../../../libs/?.lua"
package.path = package.path .. ";../../../../libs/?.lua"
package.path = package.path .. ";../../../../../libs/?.lua"
package.path = package.path .. ";../../../../../../libs/?.lua"
package.path = package.path .. ";../../../libs/macro/snabb/?.lua"
package.path = package.path .. ";../../../../libs/macro/snabb/?.lua"
package.path = package.path .. ";../../../../../libs/macro/snabb/?.lua"
local ffi = require("ffi")
local app  = require("core.app")
local link = require("core.link")
local packet = require("core.packet")
local pcap = require("lib.pcap.pcap")
local base64 = require('base64')

client = require('lclient')
client.bootstrap()
client.set_mode(1)
client.connect_to_worker(0)
client.set_module_file(nil)
client.send_modules(client.get_config()[1])

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

function sgx_encrypt(data, len)
	-- generate the string
    local d2s = ffi.string(data, len)
    d2s = 'hahaxd' .. d2s
    to_send = {}
	-- send the mode for crypto / 1 = encrypt, 0 decrypt
    to_send.mode = opt
	-- encode with base64 so we avoid weird characters on json
    to_send.data = base64.encode(d2s)
	-- remote offloading
    local res = vpn.exec(to_send)
	-- base64 decrypt the date
    return base64.decode(res)
end

function SGXWriter:push ()
    while not link.empty(self.input.input) do
        local p = link.receive(self.input.input)
        pcap.write_record_header(self.file, p.length)
        -- do the remote offloading 
        --local d = sgx_encrypt(p.data, p.length)
        -- we have the results
        bytes_sent = 1 + bytes_sent + p.length
        packets = packets + 1
		-- write the payload to the file
        self.file:write('d') 
        self.file:flush()
        packet.free(p)
    end
end
