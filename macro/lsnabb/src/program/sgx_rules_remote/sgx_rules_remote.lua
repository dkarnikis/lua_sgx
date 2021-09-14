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
    if fw.total_pkts > 200 then
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
            [[match {dst net 0.0.0.0            or             
            dst net 0.0.0.02            or                             
            dst net 0.0.3.5         or                                 
            dst net 0.1.0.30            or                             
            dst net 0.1.0.33            or                             
            dst net 0.1.0.35            or                             
            dst net 0.1.0.38            or                             
            dst net 0.1.1.1         or                                 
            dst net 0.1.1.27            or                             
            dst net 0.1.1.31            or                             
            dst net 0.1.1.37            or                             
            dst net 0.1.2.5         or                                 
            dst net 0.1.2.7         or                                 
            dst net 0.1.2.8         or                                 
            dst net 0.1.3.57            or                             
            dst net 0.1.4.5         or                                 
            dst net 0.1.4.6         or                                 
            dst net 0.1.4.8         or                                 
            dst net 0.1.5.0         or                                 
            dst net 0.1.5.1         or                                 
            dst net 0.1.5.2         or                                 
            dst net 0.1.5.3         or                                 
            dst net 0.1.5.5         or                                 
            dst net 0.1.5.6         or                                 
            dst net 0.1.6.3         or                                 
            dst net 0.1.8.6         or                                 
            dst net 0.1.9.1         or                                 
            dst net 0.2.0.5         or                                 
            dst net 0.2.0.6         or                                 
            dst net 0.2.1.17            or                             
            dst net 0.2.1.63            or                             
            dst net 0.2.2.69            or                             
            dst net 0.2.8.2         or                                 
            dst net 0.3.1.73            or                             
            dst net 0.3.25.05           or                             
            dst net 0.30.5.121          or                             
            dst net 0.4.18.0            or                             
            dst net 0.5.0.0         or                                 
            dst net 0.6.0.0         or                                 
            dst net 0.60.10.00          or                             
            dst net 0.84.0.0            or                             
            dst net 0.9.0.181           or                             
            dst net 0.9.0.2         or                                 
            dst net 0.9.0.5         or                                 
            dst net 0.9.0.8         or                                 
            dst net 0.9.1.1         or                                 
            dst net 0.9.2.1         or                                 
            dst net 0.9.2.219           or                             
            dst net 0.9.3.1         or                                 
            dst net 0.9.5.1         or                                 
            dst net 0.9.6.1         or                                 
            dst net 0.9.8.1         or                                 
            dst net 0.9.9.0         or                                 
            dst net 0.99.0.53           or                             
            dst net 0.99.1.0            or                             
            dst net 0.99.1.1            or                             
            dst net 0.99.1.2            or                             
            dst net 0.99.1.3            or                             
            dst net 0.99.1.4            or                             
            dst net 0.99.2.0            or                             
            dst net 0.99.3.0            or                             
            dst net 0.99.4.2            or                             
            dst net 00.00.04.010            or                         
            dst net 000.0.1.77          or                             
            dst net 000.0.8.18          or                             
            dst net 000.0.8.21          or                             
            dst net 000.1.02.000            or                         
            dst net 000.1.4.11          or                             
            dst net 000.7.6.49          or                             
            dst net 001.0.7.10          or                             
            dst net 001.1.5.0           or                             
            dst net 002.3.1.21          or                             
            dst net 002.3.3.31          or                             
            dst net 002.3.4.16          or                             
            dst net 002.3.5.23          or                             
            dst net 002.8.0.0           or                             
            dst net 003.0.03.060            or                         
            dst net 003.3.7.22          or                             
            dst net 003.5.29.55         or                             
            dst net 003.5.31.58         or                             
            dst net 003.5.34.61         or                             
            dst net 003.5.38.66         or                             
            dst net 003.5.40.68         or                             
            dst net 005.134.22.125          or                         
            dst net 005.8.02.6          or                             
            dst net 006.07.25.05            or                         
            dst net 006.1.00.1          or                             
            dst net 99.9.5.15 =>drop; otherwise =>drop]]}              



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
            engine.main({done = df, report = { showapps=true }})
            local x2 = gettimeofday()
            print(string.format("E2E %.10f ", (x2 - x)))
        end