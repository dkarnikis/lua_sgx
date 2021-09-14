module(..., package.seeall)

local lib = require("core.lib")
local setup = require("program.lwaftr.setup")
local util = require("program.lwaftr.check.util")
local engine = require("core.app")
local counters = require("program.lwaftr.counters")

local function show_usage(code)
   print(require("program.lwaftr.check.README_inc"))
   main.exit(code)
end

local function parse_args (args)
   local handlers = {}
   local opts = {}
   function handlers.h() show_usage(0) end
   function handlers.r() opts.r = true end
   handlers["on-a-stick"] = function ()
      opts["on-a-stick"] = true
   end
   handlers.D = function(dur)
      opts["duration"] = tonumber(dur)
   end
   args = lib.dogetopt(args, handlers, "hrD:",
      { help="h", regen="r", duration="D", ["on-a-stick"] = 0 })
   if #args ~= 5 and #args ~= 6 then show_usage(1) end
   if not opts["duration"] then opts["duration"] = 0.10 end
   return opts, args
end

local function fix_nondeterminacy()
   require('apps.ipv4.fragment').use_deterministic_first_fragment_id()
   require('apps.ipv6.fragment').use_deterministic_first_fragment_id()
end

function run(args)
   fix_nondeterminacy()

   local opts, args = parse_args(args)
   local load_check = opts["on-a-stick"] and setup.load_check_on_a_stick
                                         or  setup.load_check
   local conf_file, inv4_pcap, inv6_pcap, outv4_pcap, outv6_pcap, counters_path =
      unpack(args)
   local conf = setup.read_config(conf_file)
   local c = config.new()
   load_check(c, conf, inv4_pcap, inv6_pcap, outv4_pcap, outv6_pcap)
   engine.configure(c)
   if counters_path then
      local initial_counters = counters.read_counters()
      engine.main({duration=opts.duration})
      local final_counters = counters.read_counters()
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
