module(...,package.seeall)

local ffi = require("ffi")

local app  = require("core.app")
local link = require("core.link")
local packet = require("core.packet")
local pcap = require("lib.pcap.pcap")
local json = require("dkjson")
SGXReader = {}
mode = 0
packets = 0
encrypted = " "
bytes_sent = 0;
bytes_sent_og = 0;
aead = 2887
js = 22416
poly = 7095
code = 1305
chacha = 6973
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
    file:write(mode)
    file:write(ffi.string(data, len))
    file:close()

end

function sleep(n)
    os.execute("sleep " .. tonumber(n))
end

function sgx_encrypt(data, len)
    write_data_to_file(data, len, "../haha/out")
	cmd=("cd ../haha; ./client -s 139.91.90.18 -p 8888 -i t.lua -n 5 -m dkjson.lua -m out -m aead_chacha_poly.lua -m chacha20.lua -m poly1305.lua ".. encrypted)--./lua_vm -l -i t.lua > xd; sed -i '$ d' xd; cat xd")
	local handle = io.popen(cmd)                              
	local result = handle:read("*a")                          
	handle:close()                                            
	local str = json.decode (result)                          
    return str
end

function SGXWriter:push ()
   while not link.empty(self.input.input) do
      local p = link.receive(self.input.input)
      pcap.write_record_header(self.file, p.length)
	  -- intermediate code to perform the encryption 
	  -- encryption part
      local d = sgx_encrypt(p.data, p.length)
	  bytes_sent = 1 + bytes_sent + chacha + aead + js + poly + code + p.length
	  bytes_sent_og = bytes_sent_og + 1 + code + p.length
      packets = packets + 1
      -- XXX expensive to create interned Lua string.
      self.file:write(d) -- ffi.string(p.data, p.length))
      self.file:flush()
      packet.free(p)
   end
end
