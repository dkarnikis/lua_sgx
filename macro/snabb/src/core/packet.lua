-- Use of this source code is governed by the Apache 2.0 license; see COPYING.

module(...,package.seeall)

local debug = _G.developer_debug

local ffi = require("ffi")
local bit = require("bit")
local C = ffi.C

local lib      = require("core.lib")
local memory   = require("core.memory")
local shm      = require("core.shm")
local counter  = require("core.counter")
local sync     = require("core.sync")

require("core.packet_h")

local packet_t = ffi.typeof("struct packet")
local packet_ptr_t = ffi.typeof("struct packet *")
local packet_size = ffi.sizeof(packet_t)
max_payload = tonumber(C.PACKET_PAYLOAD_SIZE)

-- For operations that add or remove headers from the beginning of a
-- packet, instead of copying around the payload we just move the
-- packet structure as a whole around.
local packet_alignment = 512
local default_headroom = 256
-- The Intel82599 driver requires even-byte alignment, so let's keep
-- things aligned at least this much.
local minimum_alignment = 2

local function get_alignment (addr, alignment)
   -- Precondition: alignment is a power of 2.
   return bit.band(addr, alignment - 1)
end
local function get_headroom (ptr)
   return get_alignment(ffi.cast("uint64_t", ptr), packet_alignment)
end
local function is_aligned (addr, alignment)
   return get_alignment(addr, alignment) == 0
end
local function headroom_valid (headroom)
   return 0 <= headroom and headroom < packet_alignment
      and is_aligned(headroom, minimum_alignment)
end

-- Freelist containing empty packets ready for use.

local max_packets = 1e6

ffi.cdef([[
struct freelist {
    int32_t lock[1];
    uint64_t nfree;
    uint64_t max;
    struct packet *list[]]..max_packets..[[];
};
]])

local function freelist_create(name)
   local fl = shm.create(name, "struct freelist")
   fl.max = max_packets
   return fl
end

local function freelist_open(name, readonly)
   return shm.open(name, "struct freelist", readonly)
end

local function freelist_full(freelist)
   return freelist.nfree == freelist.max
end

local function freelist_add(freelist, element)
   -- Safety check
   if _G.developer_debug then
      assert(not freelist_full(freelist), "freelist overflow")
   end
   freelist.list[freelist.nfree] = element
   freelist.nfree = freelist.nfree + 1
end

local function freelist_remove(freelist)
   if freelist.nfree == 0 then
      error("no free packets")
   else
      freelist.nfree = freelist.nfree - 1
      return freelist.list[freelist.nfree]
   end
end

local function freelist_nfree(freelist)
   return freelist.nfree
end

local function freelist_lock(freelist)
   sync.lock(freelist.lock)
end

local function freelist_unlock(freelist)
   sync.unlock(freelist.lock)
end

local packet_allocation_step = 1000
local packets_allocated = 0
 -- Initialized on demand.
local packets_fl, group_fl

-- Call to ensure packet freelist is enabled.
function initialize ()
   packets_fl = freelist_create("engine/packets.freelist")
end

-- Call to ensure group freelist is enabled.
function enable_group_freelist ()
   if not group_fl then
      group_fl = freelist_create("group/packets.freelist")
   end
end

-- Return borrowed packets to group freelist.
function rebalance_freelists ()
   if group_fl and freelist_nfree(packets_fl) > packets_allocated then
      freelist_lock(group_fl)
      while freelist_nfree(packets_fl) > packets_allocated
      and not freelist_full(group_fl) do
         freelist_add(group_fl, freelist_remove(packets_fl))
      end
      freelist_unlock(group_fl)
   end
end

-- Register struct freelist as an abstract SHM object type so that the group
-- freelist can be recognized by shm.open_frame and described with tostring().
shm.register(
   'freelist',
   {open = function (name) return shm.open(name, "struct freelist") end}
)
ffi.metatype("struct freelist", {__tostring = function (freelist)
   return ("%d/%d"):format(tonumber(freelist.nfree), tonumber(freelist.max))
end})

-- Return an empty packet.
function allocate ()
   if freelist_nfree(packets_fl) == 0 then
      if group_fl then
         freelist_lock(group_fl)
         while freelist_nfree(group_fl) > 0
         and freelist_nfree(packets_fl) < packets_allocated do
            freelist_add(packets_fl, freelist_remove(group_fl))
         end
         freelist_unlock(group_fl)
      end
      if freelist_nfree(packets_fl) == 0 then
         preallocate_step()
      end
   end
   return freelist_remove(packets_fl)
end

-- Release all packets allocated by pid to its group freelist (if one exists.)
--
-- This is an internal API function provided for cleanup during
-- process termination.
function shutdown (pid)
   local in_group, group_fl = pcall(
      freelist_open, "/"..pid.."/group/packets.freelist"
   )
   if in_group then
      local packets_fl = freelist_open("/"..pid.."/engine/packets.freelist")
      freelist_lock(group_fl)
      while freelist_nfree(packets_fl) > 0 do
         freelist_add(group_fl, freelist_remove(packets_fl))
      end
      freelist_unlock(group_fl)
   end
end

-- Create a new empty packet.
function new_packet ()
   local base = memory.dma_alloc(packet_size + packet_alignment,
                                 packet_alignment)
   local p = ffi.cast(packet_ptr_t, base + default_headroom)
   p.length = 0
   return p
end

-- Create an exact copy of a packet.
function clone (p)
   return from_pointer(p.data, p.length)
end

-- Append data to the end of a packet.
function append (p, ptr, len)
   assert(p.length + len <= max_payload, "packet payload overflow")
   ffi.copy(p.data + p.length, ptr, len)
   p.length = p.length + len
   return p
end

-- Prepend data to the start of a packet.
function prepend (p, ptr, len)
   p = shiftright(p, len)
   ffi.copy(p.data, ptr, len)                -- Fill the gap
   return p
end

-- Move packet data to the left. This shortens the packet by dropping
-- the header bytes at the front.
function shiftleft (p, bytes)
   assert(0 <= bytes and bytes <= p.length)
   local ptr = ffi.cast("char*", p)
   local len = p.length
   local headroom = get_headroom(ptr)
   if headroom_valid(bytes + headroom) then
      -- Fast path: just shift the packet pointer.
      p = ffi.cast(packet_ptr_t, ptr + bytes)
      p.length = len - bytes
      return p
   else
      -- Slow path: shift packet data, resetting the default headroom.
      local delta_headroom = default_headroom - headroom
      C.memmove(p.data + delta_headroom, p.data + bytes, len - bytes)
      p = ffi.cast(packet_ptr_t, ptr + delta_headroom)
      p.length = len - bytes
      return p
   end
end

-- Move packet data to the right. This leaves length bytes of data
-- at the beginning of the packet.
function shiftright (p, bytes)
   local ptr = ffi.cast("char*", p)
   local len = p.length
   local headroom = get_headroom(ptr)
   if headroom_valid(headroom - bytes) then
      -- Fast path: just shift the packet pointer.
      p = ffi.cast(packet_ptr_t, ptr - bytes)
      p.length = len + bytes
      return p
   else
      -- Slow path: shift packet data, resetting the default headroom.
      assert(bytes <= max_payload - len)
      local delta_headroom = default_headroom - headroom
      C.memmove(p.data + bytes + delta_headroom, p.data, len)
      p = ffi.cast(packet_ptr_t, ptr + delta_headroom)
      p.length = len + bytes
      return p
   end
end

-- Conveniently create a packet by copying some existing data.
function from_pointer (ptr, len)
   return append(allocate(), ffi.cast("uint8_t *", ptr), len)
end
function from_string (d)         return from_pointer(d, #d) end

-- Free a packet that is no longer in use.
local function free_internal (p)
   local ptr = ffi.cast("char*", p)
   p = ffi.cast(packet_ptr_t, ptr - get_headroom(ptr) + default_headroom)
   p.length = 0
   freelist_add(packets_fl, p)
end   

function account_free (p)
   counter.add(engine.frees)
   counter.add(engine.freebytes, p.length)
   -- Calculate bits of physical capacity required for packet on 10GbE
   -- Account for minimum data size and overhead of CRC and inter-packet gap
   counter.add(engine.freebits, (math.max(p.length, 46) + 4 + 5) * 8)
end

function free (p)
   account_free(p)
   free_internal(p)
end

-- Set packet data length.
function resize (p, len)
   assert(len <= max_payload, "packet payload overflow")
   ffi.fill(p.data + p.length, math.max(0, len - p.length))
   p.length = len
   return p
end

function preallocate_step()
   assert(packets_allocated + packet_allocation_step <= max_packets,
          "packet allocation overflow")

   for i=1, packet_allocation_step do
      free_internal(new_packet(), true)
   end
   packets_allocated = packets_allocated + packet_allocation_step
   packet_allocation_step = 2 * packet_allocation_step
end

function selftest ()
   assert(is_aligned(0, 1))
   assert(is_aligned(1, 1))
   assert(is_aligned(2, 1))
   assert(is_aligned(3, 1))

   assert(    is_aligned(0, 2))
   assert(not is_aligned(1, 2))
   assert(    is_aligned(2, 2))
   assert(not is_aligned(3, 2))

   assert(    is_aligned(0, 512))
   assert(not is_aligned(1, 512))
   assert(not is_aligned(2, 512))
   assert(not is_aligned(3, 512))
   assert(not is_aligned(510, 512))
   assert(not is_aligned(511, 512))
   assert(    is_aligned(512, 512))
   assert(not is_aligned(513, 512))

   local function is_power_of_2 (x) return bit.band(x, x-1) == 0 end
   assert(is_power_of_2(minimum_alignment))
   assert(is_power_of_2(packet_alignment))
   assert(is_aligned(default_headroom, minimum_alignment))

   local function check_free (p)
      free(p)
      -- Check that the last packet added to the free list has the
      -- default headroom.
      local p = allocate()
      assert(get_headroom(p) == default_headroom)
      free(p)
   end

   local function check_shift(init_len, shift, amount, len, headroom)
      local p = allocate()
      p.length = init_len
      p = shift(p, amount)
      assert(p.length == len)
      assert(get_headroom(p) == headroom)
      check_free(p)
   end
   local function check_fast_shift(init_len, shift, amount, len, headroom)
      assert(headroom_valid(amount))
      check_shift(init_len, shift, amount, len, headroom)
   end
   local function check_slow_shift(init_len, shift, amount, len)
      check_shift(init_len, shift, amount, len, default_headroom)
   end

   check_fast_shift(0, function (p, amt) return p end, 0, 0, default_headroom)
   check_fast_shift(0, shiftright, 0, 0, default_headroom)
   check_fast_shift(0, shiftright, 10, 10, default_headroom - 10)
   check_slow_shift(0, shiftright, 11, 11)

   check_fast_shift(512, shiftleft, 0, 512, default_headroom)
   check_fast_shift(512, shiftleft, 10, 502, default_headroom + 10)
   check_slow_shift(512, shiftleft, 11, 501)

   check_fast_shift(0, shiftright, default_headroom, default_headroom, 0)
   check_slow_shift(0, shiftright, default_headroom + 2, default_headroom + 2)
   check_slow_shift(0, shiftright, packet_alignment * 2, packet_alignment * 2)

   check_fast_shift(packet_alignment, shiftleft,
                    packet_alignment - default_headroom - 2,
                    default_headroom + 2, packet_alignment - 2)
   check_slow_shift(packet_alignment, shiftleft,
                    packet_alignment - default_headroom, default_headroom)
end
