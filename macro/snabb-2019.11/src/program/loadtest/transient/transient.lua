module(..., package.seeall)

local engine = require("core.app")
local counter = require("core.counter")
local config = require("core.config")
local pci = require("lib.hardware.pci")
local basic_apps = require("apps.basic.basic_apps")
local loadgen = require("apps.lwaftr.loadgen")
local main = require("core.main")
local PcapReader = require("apps.pcap.pcap").PcapReader
local lib = require("core.lib")
local numa = require("lib.numa")
local promise = require("program.loadtest.promise")
local lwutil = require("apps.lwaftr.lwutil")

local WARM_UP_BIT_RATE = 5e9
local WARM_UP_TIME = 2

local function fatal (msg)
   print(msg)
   main.exit(1)
end

local function show_usage(code)
   print(require("program.loadtest.transient.README_inc"))
   main.exit(code)
end

local function find_devices(pattern)
   if #pci.devices == 0 then pci.scan_devices() end
   pattern = pci.qualified(pattern)
   local ret = {}
   for _,device in ipairs(pci.devices) do
      if device.driver and pattern:match(device.pciaddress) then
         table.insert(ret, device.pciaddress)
      end
   end
   return ret
end

local function find_device(pattern)
   local devices = find_devices(pattern)
   if #devices == 0 then
      error('no devices matched pattern "'..pattern..'"')
   elseif #devices == 1 then
      return devices[1]
   else
      local devices_str = table.concat(devices, ' ')
      error('multiple devices matched pattern "'..pattern..'":'..devices_str)
   end
end

local programs = {}

function programs.ramp_up(tester, opts)
   local function next(step)
      if step <= math.ceil(opts.bitrate / opts.step) then
         return tester.measure(math.min(opts.bitrate, opts.step * step),
                               opts.duration,
                               opts.bench_file,
                               opts.hydra):
            and_then(next, step + 1)
      end
   end
   return next(1)
end

function programs.ramp_down(tester, opts)
   local function next(step)
      if step >= 1 then
         return tester.measure(math.min(opts.bitrate, opts.step * step),
                               opts.duration,
                               opts.bench_file,
                               opts.hydra):
            and_then(next, step - 1)
      end
   end
   return next(math.ceil(opts.bitrate / opts.step))
end

function programs.ramp_up_down(tester, opts)
   return programs.ramp_up(tester, opts)
      :and_then(programs.ramp_down, tester, opts)
end

function programs.constant(tester, opts)
   local function step()
      local gbps_bitrate = opts.bitrate/1e9
      local start_counters = tester.record_counters()
      local function report()
         local end_counters = tester.record_counters()
         tester.print_counter_diff(start_counters, end_counters,
                                   opts.duration, gbps_bitrate,
                                   opts.bench_file, opts.hydra_mode)
      end
      -- No quiet period; keep the packets going!
      return tester.generate_load(opts.bitrate, opts.duration):
         and_then(report):
         and_then(step)
   end
   print(string.format('Applying %f Gbps of load.', opts.bitrate/1e9))
   return step()
end

function parse_args(args)
   local handlers = {}
   local opts = { bitrate = 10e9, duration = 5, program=programs.ramp_up_down }
   local cpu
   function handlers.b(arg)
      opts.bitrate = assert(tonumber(arg), 'bitrate must be a number')
   end
   function handlers.cpu(arg)
      cpu = tonumber(arg)
      if not cpu or cpu ~= math.floor(cpu) or cpu < 0 then
         fatal("Invalid cpu number: "..arg)
      end
   end
   function handlers.s(arg)
      opts.step = assert(tonumber(arg), 'step must be a number')
   end
   function handlers.D(arg)
      opts.duration = assert(tonumber(arg), 'duration must be a number')
   end
   function handlers.p(arg)
      opts.program = assert(programs[arg], 'unrecognized program: '..arg)
   end
   function handlers.y() opts.hydra = true end
   handlers["bench-file"] = function(arg)
      opts.bench_file = arg
   end
   function handlers.h() show_usage(0) end
   args = lib.dogetopt(args, handlers, "yhb:s:D:p:",
                       { bitrate="b", step="s", duration="D", help="h",
                         program="p", cpu=1, ["bench-file"]=1, hydra="y" })
   if not opts.step then opts.step = opts.bitrate / 10 end
   assert(opts.bitrate > 0, 'bitrate must be positive')
   assert(opts.step > 0, 'step must be positive')
   assert(opts.duration > 0, 'duration must be positive')
   if #args == 0 or #args % 4 ~= 0 then show_usage(1) end
   local streams = {}
   local streams_by_tx_id = {}
   local pci_addrs = {}
   for i=1,#args,4 do
      local capture_file, tx, rx, pattern = args[i], args[i+1], args[i+2], args[i+3]
      local stream = {
         capture_file = capture_file,
         tx_name = tx,
         rx_name = rx,
         tx_id = tx:gsub('[^%w]', '_'),
         rx_id = rx:gsub('[^%w]', '_'),
         device = pci.device_info(find_device(pattern))
      }
      table.insert(streams, stream)
      assert(streams_by_tx_id[stream.tx_id] == nil, 'Duplicate: '..stream.tx_id)
      streams_by_tx_id[stream.tx_id] = stream
      table.insert(pci_addrs, stream.device.pciaddress)
   end
   for _, stream in ipairs(streams) do
      assert(streams_by_tx_id[stream.rx_id], 'Missing stream: '..stream.rx_id)
      stream.rx_device = streams_by_tx_id[stream.rx_id].device
   end
   if cpu then numa.bind_to_cpu(cpu) end
   numa.check_affinity_for_pci_addresses(pci_addrs)
   return opts, streams
end

local function read_counters(link)
   return {
      txpackets = counter.read(link.stats.txpackets),
      txbytes = counter.read(link.stats.txbytes)
   }
end

local function diff_counters(a, b)
   return {
      txpackets = tonumber(b.txpackets - a.txpackets),
      txbytes = tonumber(b.txbytes - a.txbytes)
   }
end

function run(args)
   local opts, streams = parse_args(args)
   local c = config.new()
   for _,stream in ipairs(streams) do
      local driver = require(stream.device.driver).driver

      stream.pcap_id = 'pcap_'..stream.tx_id
      stream.repeater_id = 'repeater_'..stream.tx_id
      stream.nic_tx_id = 'nic_'..stream.tx_id
      stream.nic_rx_id = 'nic_'..stream.rx_id
      -- Links are named directionally with respect to NIC apps, but we
      -- want to name tx and rx with respect to the whole network
      -- function.
      stream.nic_tx_link = stream.device.rx
      stream.nic_rx_link = stream.rx_device.tx
      stream.rx_sink_id = 'rx_sink_'..stream.rx_id

      config.app(c, stream.pcap_id, PcapReader, stream.capture_file)
      config.app(c, stream.repeater_id, loadgen.RateLimitedRepeater, {})
      config.app(c, stream.nic_tx_id, driver,
                 { pciaddr = stream.device.pciaddress })
      config.app(c, stream.rx_sink_id, basic_apps.Sink)

      local function link(src_app, src_link, sink_app, sink_link)
         config.link(c, src_app..'.'..src_link..' -> '..sink_app..'.'..sink_link)
      end

      link(stream.pcap_id, "output", stream.repeater_id, "input")
      link(stream.repeater_id, "output", stream.nic_tx_id, stream.nic_tx_link)
      link(stream.nic_rx_id, stream.nic_rx_link, stream.rx_sink_id, "input")
   end
   engine.configure(c)

   local tester = {}

   function tester.adjust_rates(bit_rate)
      for _,stream in ipairs(streams) do
         local app = engine.app_table[stream.repeater_id]
         app:set_rate(bit_rate)
      end
   end

   function tester.generate_load(bitrate, duration)
      tester.adjust_rates(bitrate)
      return promise.Wait(duration):and_then(tester.adjust_rates, 0)
   end

   function tester.warm_up()
      print(string.format("Warming up at %f Gb/s for %s seconds.",
                          WARM_UP_BIT_RATE / 1e9, WARM_UP_TIME))
      return tester.generate_load(WARM_UP_BIT_RATE, WARM_UP_TIME):
         and_then(promise.Wait, 0.5)
   end

   function tester.record_counters()
      local ret = {}
      for _, stream in ipairs(streams) do
         local tx_nic = assert(engine.app_table[stream.nic_tx_id],
                               "NIC "..stream.nic_tx_id.." not found")
         local rx_nic = assert(engine.app_table[stream.nic_rx_id],
                               "NIC "..stream.nic_rx_id.." not found")
         ret[stream.nic_tx_id] = {
            tx = read_counters(tx_nic.input[stream.nic_tx_link]),
            rx = read_counters(rx_nic.output[stream.nic_rx_link]),
            drop = rx_nic:rxdrop()
         }
      end
      return ret
   end

   function tester.print_counter_diff(
         before, after, duration, gbps_bitrate, bench_file, hydra_mode)
      local function bitrate(diff)
         -- 7 bytes preamble, 1 start-of-frame, 4 CRC, 12 interpacket gap.
         local overhead = 7 + 1 + 4 + 12
         return (diff.txbytes + diff.txpackets * overhead) * 8 / duration
      end
      for _, stream in ipairs(streams) do
         print(string.format('  %s:', stream.tx_name))
         local nic_id = stream.nic_tx_id
         local nic_before, nic_after = before[nic_id], after[nic_id]
         local tx = diff_counters(nic_before.tx, nic_after.tx)
         local tx_mpps = tx.txpackets / duration / 1e6
         local tx_gbps = bitrate(tx) / 1e9
         local rx = diff_counters(nic_before.rx, nic_after.rx)
         local rx_mpps = rx.txpackets / duration / 1e6
         local rx_gbps = bitrate(rx) / 1e9
         local drop = tonumber(nic_after.drop - nic_before.drop)
         local lost_packets = (tx.txpackets - rx.txpackets) - drop
         local lost_percent = (tx.txpackets - rx.txpackets) / tx.txpackets * 100
         print(string.format('    TX %d packets (%f MPPS), %d bytes (%f Gbps)',
            tx.txpackets, tx_mpps, tx.txbytes, tx_gbps))
         print(string.format('    RX %d packets (%f MPPS), %d bytes (%f Gbps)',
            rx.txpackets, rx_mpps, rx.txbytes, rx_gbps))
         print(string.format('    Loss: %d ingress drop + %d packets lost (%f%%)',
            drop, lost_packets, lost_percent))
         if bench_file then
            if hydra_mode then
               -- NOTE: all the stats below are available: the commented out ones
               --   will not show in Hydra reports. They are too many, making the
               --   graphs unreadable, and most are redundant anyway.
               -- TX
               --   (Hydra reports prefer integers for the X (time) axis.)
               -- bench_file:write(('%s_tx_packets,%.f,%f,packets\n'):format(
               --    stream.tx_name,gbps_bitrate,tx.txpackets))
               -- bench_file:write(('%s_tx_mpps,%.f,%f,mpps\n'):format(
               --    stream.tx_name,gbps_bitrate,tx_mpps))
               -- bench_file:write(('%s_tx_bytes,%.f,%f,bytes\n'):format(
               --    stream.tx_name,gbps_bitrate,tx.txbytes))
               -- bench_file:write(('%s_tx_gbps,%.f,%f,gbps\n'):format(
               --    stream.tx_name,gbps_bitrate,tx_gbps))
               -- RX
               -- bench_file:write(('%s_rx_packets,%.f,%f,packets\n'):format(
               --    stream.tx_name,gbps_bitrate,rx.txpackets))
               bench_file:write(('%s_rx_mpps,%.f,%f,mpps\n'):format(
                  stream.tx_name,gbps_bitrate,rx_mpps))
               -- bench_file:write(('%s_rx_bytes,%.f,%f,bytes\n'):format(
               --    stream.tx_name,gbps_bitrate,rx.txbytes))
               bench_file:write(('%s_rx_gbps,%.f,%f,gbps\n'):format(
                  stream.tx_name,gbps_bitrate,rx_gbps))
               -- Loss
               bench_file:write(('%s_ingress_drop,%.f,%f,packets\n'):format(
                  stream.tx_name,gbps_bitrate,drop))
               -- bench_file:write(('%s_lost_packets,%.f,%f,packets\n'):format(
               --    stream.tx_name,gbps_bitrate,lost_packets))
               bench_file:write(('%s_lost_percent,%.f,%f,percentage\n'):format(
                  stream.tx_name,gbps_bitrate,lost_percent))
            else
               bench_file:write(('%f,%s,%d,%f,%d,%f,%d,%f,%d,%f,%d,%d,%f\n'):format(
                  gbps_bitrate, stream.tx_name,
                  tx.txpackets, tx_mpps, tx.txbytes, tx_gbps,
                  rx.txpackets, rx_mpps, rx.txbytes, rx_gbps,
                  drop, lost_packets, lost_percent))
            end
         end
      end
      if bench_file then
         bench_file:flush()
      end
   end

   function tester.measure(bitrate, duration, bench_file, hydra_mode)
      local gbps_bitrate = bitrate/1e9
      local start_counters = tester.record_counters()
      local function report()
         local end_counters = tester.record_counters()
         tester.print_counter_diff(start_counters, end_counters, duration,
            gbps_bitrate, bench_file, hydra_mode)
      end
      print(string.format('Applying %f Gbps of load.', gbps_bitrate))
      return tester.generate_load(bitrate, duration):
         -- Wait 2ms for packets in flight to arrive
         and_then(promise.Wait, 0.002):
         and_then(report)
   end

   local function create_bench_file(filename, hydra_mode)
      local bench_file = io.open(filename, "w")
      local header = hydra_mode and "benchmark,id,score,unit\n" or
         "load_gbps,stream,tx_packets,tx_mpps,tx_bytes,tx_gbps,rx_packets"..
         ",rx_mpps,rx_bytes,rx_gbps,ingress_drop,lost_packets,lost_percent\n"
      bench_file:write(header)
      bench_file:flush()
      return bench_file
   end

   local function run_engine(tail)
      local is_done = false
      local function mark_done() is_done = true end
      tail:and_then(mark_done)
      local function done() return is_done end
      engine.main({done=done})
   end

   if opts.bench_file then
      opts.bench_file = create_bench_file(opts.bench_file, opts.hydra)
   end
   engine.busywait = true
   local head = promise.new()
   run_engine(tester.warm_up()
                 :and_then(opts.program, tester, opts))
end
