-- Use of this source code is governed by the Apache 2.0 license; see COPYING.

module(..., package.seeall)

local S = require("syscall")
local lib = require("core.lib")
local numa = require("lib.numa")
local ingress_drop_monitor = require("lib.timers.ingress_drop_monitor")

local function fatal (msg)
   print(msg)
   main.exit(1)
end

local scheduling_opts = {
   cpu = {},                  -- CPU index (integer).
   real_time = {},            -- Boolean.
   ingress_drop_monitor = {}, -- Action string: one of 'flush' or 'warn'.
   busywait = {default=true}, -- Boolean.
   eval = {}                  -- String.
}

local sched_apply = {}

function sched_apply.cpu (cpu)
   print(string.format('Binding data-plane PID %s to CPU %s.',
                       tonumber(S.getpid()), cpu))
   numa.bind_to_cpu(cpu)
end

function sched_apply.ingress_drop_monitor (action)
   timer.activate(ingress_drop_monitor.new({action=action}):timer())
end

function sched_apply.real_time (real_time)
   if real_time and not S.sched_setscheduler(0, "fifo", 1) then
      fatal('Failed to enable real-time scheduling.  Try running as root.')
   end
end

function sched_apply.busywait (busywait)
   engine.busywait = busywait
end

function sched_apply.eval (str)
   loadstring(str)()
end

function apply (opts)
   opts = lib.parse(opts, scheduling_opts)
   for k, v in pairs(opts) do sched_apply[k](v) end
end

local function stringify (x)
   if type(x) == 'string' then return string.format('%q', x) end
   if type(x) == 'number' then return tostring(x) end
   if type(x) == 'boolean' then return x and 'true' or 'false' end
   assert(type(x) == 'table')
   local ret = {"{"}
   local first = true
   for k,v in pairs(x) do
      if first then first = false else table.insert(ret, ",") end
      table.insert(ret, string.format('[%s]=%s', stringify(k), stringify(v)))
   end
   table.insert(ret, "}")
   return table.concat(ret)
end

function stage (opts)
   return string.format("require('lib.scheduling').apply(%s)",
                        stringify(lib.parse(opts, scheduling_opts)))
end

function selftest ()
   print('selftest: lib.scheduling')
   loadstring(stage({}))()
   loadstring(stage({busywait=false}))()
   loadstring(stage({eval='print("lib.scheduling: eval test")'}))()
   print('selftest: ok')
end
