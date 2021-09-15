-- example_firewall.lua

module(..., package.seeall)
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




-- basic module imports
local raw  = require("apps.socket.raw")
local pcap = require("apps.pcap.pcap")
local spy  = require("apps.wall.l7spy")
local fw   = require("apps.wall.l7fw")
local ndpi = require("apps.wall.scanner.ndpi")

-- configuration parameters for the l7fw
-- replace these with the appropriate values for your firewall host
-- for testing purposes, any values are ok
local host_ip  = "192.168.1.8"
local host_mac = "01:23:45:67:89:ab"

function df()
    if fw.pkts_proc > 1 then
        return true
    end
    return false
end

function run (args)

    local x = gettimeofday()
    -- an nDPI scanner instance for l7spy and l7fw
    local s = ndpi:new()
    -- configuration of the Snabb app network
    local c = config.new()
    fw.load_lib(args[3])
    local rules = { 
        DNS = [[match { src net 10.1.1.4 and flow_count > 10 => accept; otherwise => drop;}]],
        NFS = [[ match { flow_count <8 or src net 139.25.22.2 => drop; otherwise =>accept;}]],
        NETBIOS = [[match {flow_count >= 10 and src net 111.111.111.111 => accept;
        otherwise => drop}]],
        BITTORRENT = [[match { flow_count >= 5 and
        dst net 10.10.10.22 
            => drop;
            otherwise => accept }]],
    UNKNOWN = [[match { flow_count >= 5 and
    src net 10.1.3.143 or dst net 10.1.3.143 or src net 10.1.6.18
    or udp
    => drop;
    otherwise => accept }]],
    default = 
    [[match { flow_count >= 5 and
    dst net 10.10.10.22 or src net 10.1.3.143 or dst net 10.1.3.143 or src net 10.1.6.18
    or udp or src net 0.0.0.0 and flow_count > 5 
    => drop;
    otherwise => accept }]]}
    --
    -- configuration table for l7fw
    local fw_config = { scanner = s,
    rules = rules,
    local_ipv4 = host_ip,
    local_mac = host_mac }

    config.app(c, "net1", pcap.PcapReader, args[1])
    config.app(c, "net2", pcap.PcapWriter, args[2])

    config.app(c, "scanner", spy.L7Spy, { scanner = s })
    config.app(c, "firewall", fw.L7Fw, fw_config)

    config.link(c, "net1.output -> scanner.south")
    config.link(c, "scanner.north -> firewall.input")
    config.link(c, "firewall.output -> net2.input")
    config.link(c, "firewall.reject -> net2.input")
    engine.configure(c)
    -- run for 5 seconds and show the app reports
    engine.main({done = df, report = { showapps = true }})
    local x2 = gettimeofday()
    print(string.format("%.2f ", (x2 - x)))
end
