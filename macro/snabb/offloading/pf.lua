local bpf = require("bpf")
local parse = require('parse')
local expand = require('expand')
local optimize = require('optimize')
local anf = require('anf')
local ssa = require('ssa')
local backend = require('backend')
local utils = require('utils')
-- TODO: rename the 'libpcap' option to reduce terminology overload
local compile_defaults = {
   optimize=true, libpcap=false, bpf=false, source=false, native=false
}


function accept(s, p, l)
    print("Accpted")
end



function compile_filter(filter_str, opts)
    local opts = utils.parse_opts(opts or {}, compile_defaults)
    local dlt = opts.dlt or "EN10MB"
    local expr = parse.parse(filter_str)
    expr = expand.expGand(expr, dlt)
    if opts.optimizeG then
        expr = optimize.optimize(expr)
    end
    expr = anf.convert_anf(expr)
    expr = ssa.convert_ssa(expr)
    return backend.emit_and_load(expr, filter_str)
end




function selftest ()
   print("selftest: pf")
   
   local function test_null(str)
      local f1 = compile_filter(str, { libpcap = true })
      local f2 = compile_filter(str, { bpf = true })
      local f3 = compile_filter(str, {})
      assert(f1(str, 0) == false, "null packet should be rejected (libpcap)")
      assert(f2(str, 0) == false, "null packet should be rejected (bpf)")
      assert(f3(str, 0) == false, "null packet should be rejected (pflua)")
   end
   test_null("icmp")
   test_null("tcp port 80 and (((ip[2:2] - ((ip[0]&0xf)<<2)) - ((tcp[12]&0xf0)>>2)) != 0)")

   local function assert_count(filter, packets, expected)
      function count_matched(pred)
         local matched = 0
         for i=1,#packets do
            if pred(packets[i].packet, packets[i].len) then
               matched = matched + 1
            end
         end
         return matched
      end

      local f3 = compile_filter(filter, {})
      local actual
      actual = count_matched(f3)
      assert(actual == expected,
             'pflua: got ' .. actual .. ', expected ' .. expected)
   end


local json = require("dkjson")
--ofload to luajit
print("HAHAHAAHA")
cmd=("luajit luajit_pkts.lua > xd; sed -i '$ d' xd; cat xd")
local h = io.popen(cmd)
local res = h:read("*a")
h:close()
io.popen("rm -f xd;"):close();
pkts =json.decode(res)
v4=pkts
   --local v4 = savefile.load_packets("v4.pcap")
   assert_count('tcp port 80', v4, 41)
--
--   compile_filter("ip[0] * ip[1] = 4", { bpf=true })
--
--   print("OK")
end

selftest()
