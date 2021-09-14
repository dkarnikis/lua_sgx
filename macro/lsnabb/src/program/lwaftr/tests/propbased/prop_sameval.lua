#!/usr/bin/env luajit
module(..., package.seeall)

-- Make sure running a snabb config get twice results in the
-- same values getting returned

local genyang = require("program.lwaftr.tests.propbased.genyang")
local common  = require("program.lwaftr.tests.propbased.common")
local run_pid = {}
local current_cmd

function property()
   local xpath, schema_name = genyang.generate_config_xpath()
   local get = genyang.generate_get(run_pid[1], schema_name, xpath)
   local iters = 1
   local results, results2
   current_cmd = get

   -- occasionally do a bunch of gets/sets at once
   if math.random() < 0.01 then
      iters = math.random(100, 150)
   end

   for i=1, iters do
      results = (genyang.run_yang(get))

      if common.check_crashed(results) then
         return false
      end

      -- queried data doesn't exist most likely (or some other non-fatal error)
      if results:match("short read") then
         -- just continue because it's not worth trying to set this property
         return
      end
   end

   local set = genyang.generate_set(run_pid[1], schema_name, xpath, results)
   current_cmd = set

   for i=1, iters do
      results_set = genyang.run_yang(set)

      if common.check_crashed(results_set) then
         return false
      end
   end

   current_cmd = get
   for i=1, iters do
      results2 = (genyang.run_yang(get))

      if common.check_crashed(results2) then
         return false
      end

      if results ~= results2 then
         print("Running the same config command twice produced different outputs")
         print("\n\n\nFirst output:")
         print(results)
         print("\n\n\nSecond output:")
         print(results2)
         return false
      end
   end
end

function print_extra_information()
   print("The command was:", current_cmd)
end

handle_prop_args =
   common.make_handle_prop_args("prop_sameval", 90, run_pid)

cleanup = common.make_cleanup(run_pid)
