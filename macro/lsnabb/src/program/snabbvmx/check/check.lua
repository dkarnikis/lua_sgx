module(..., package.seeall)

local config = require("core.config")
local lib = require("core.lib")
local util = require("program.lwaftr.check.util")
local counters = require("program.lwaftr.counters")
local setup = require("program.snabbvmx.lwaftr.setup")

local function show_usage(code)
   print(require("program.snabbvmx.check.README_inc"))
   main.exit(code)
end

local function parse_args (args)
   local handlers = {}
   local opts = {}
   function handlers.h() show_usage(0) end
   function handlers.r() opts.r = true end
   args = lib.dogetopt(args, handlers, "hrD:",
      { help="h", regen="r", duration="D" })
   if #args ~= 5 and #args ~= 6 then show_usage(1) end
   if not opts.duration then opts.duration = 0.10 end
   return opts, args
end

function run(args)
   local opts, args = parse_args(args)
   local conf_file, inv4_pcap, inv6_pcap, outv4_pcap, outv6_pcap, counters_path =
      unpack(args)

   local c = config.new()
   setup.load_check(c, conf_file, inv4_pcap, inv6_pcap, outv4_pcap, outv6_pcap)
   engine.configure(c)
   if counters_path then
      local initial_counters = counters.read_counters(c)
      engine.main({duration=opts.duration})
      local final_counters = counters.read_counters(c)
      local counters_diff = util.diff_counters(final_counters,
                                               initial_counters)
      if opts.r then
         util.regen_counters(counters_diff, counters_path)
      else
         local req_counters = util.load_requested_counters(counters_path)
         util.validate_diff(counters_diff, req_counters)
      end
   else
      engine.main({duration=opts.duration})
   end
   print("done")
end
