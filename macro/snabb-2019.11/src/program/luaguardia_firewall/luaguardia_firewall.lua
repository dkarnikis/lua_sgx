module(..., package.seeall)
local pcap = require("program.luaguardia_firewall.pcap")
local ffi = require("ffi")

if pcall(ffi.typeof, "struct timeval") then
        -- check if already defined.
else
        -- undefined! let's define it!
        ffi.cdef[[
           typedef struct timeval {
                long tv_sec;
                long tv_usec;
           } timeval;

        int gettimeofday(struct timeval* t, void* tzp);
]]
end
local gettimeofday_struct = ffi.new("struct timeval")
local function gettimeofday()
        ffi.C.gettimeofday(gettimeofday_struct, nil)
        return tonumber(gettimeofday_struct.tv_sec) + tonumber(gettimeofday_struct.tv_usec) / 1000000.0
end

function hahaxd()
    if pcap.packets > 31000 then
        return true
    else
        return false
    end
end

function run(args)
    local x = gettimeofday()
    local c = config.new()
    pcap.opt = args[3]
    config.app(c, "net1", pcap.SGXReader, args[1])
    config.app(c, "net2", pcap.SGXWriter, args[2])
    config.link(c, "net1.output -> net2.input")
    engine.configure(c)
    -- run for 5 seconds and show the app reports
    engine.main({done=hahaxd, report = {showapps = true, showlinks = true}})
    local x2 = gettimeofday()
    print(string.format("E2E %.2f Packets %d BytesALL %d", x2 - x, pcap.packets, pcap.bytes_sent))
end
