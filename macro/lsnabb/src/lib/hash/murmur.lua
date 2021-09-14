-- Use of this source code is governed by the Apache 2.0 license; see COPYING.

-- Implementation of the MurmurHash3 hash function according to the
-- reference implementation
-- https://code.google.com/p/smhasher/source/browse/trunk/MurmurHash3.cpp
--
-- This implementation does not include the variant MurmurMash3_x86_128.
--
-- Note that these hash functions are dependent on the endianness of
-- the system.  The self-test as used here will only pass on
-- little-endian machines.
--
-- All hash functions take an optional value as seed.

module(..., package.seeall)
local ffi = require("ffi")
local bit = require("bit")
local base_hash = require("lib.hash.base")
local bor, band, bxor, rshift, lshift = bit.bor, bit.band, bit.bxor, bit.rshift, bit.lshift

-- Perform performance test in selftest() if set to true
local perf_enable = false

local murmur = {}

local uint8_ptr_t = ffi.typeof("uint8_t*")
local uint32_ptr_t = ffi.typeof("uint32_t*")
local uint64_ptr_t = ffi.typeof("uint64_t*")

do
   murmur.MurmurHash3_x86_32 = subClass(base_hash)
   local MurmurHash3_x86_32 = murmur.MurmurHash3_x86_32
   MurmurHash3_x86_32._name = 'MurmurHash3_x86_32'
   MurmurHash3_x86_32._size = 32

   local c1 = 0xcc9e2d51ULL
   local c2 = 0x1b873593ULL
   local c3 = 0x85ebca6bULL
   local c4 = 0xc2b2ae35ULL
   local c5 = 0xe6546b64ULL
   local max32 = 0xffffffffULL

   local tail = ffi.new("uint32_t[1]")

   function MurmurHash3_x86_32:hash (data, length, seed)
      local nblocks = rshift(length, 2)
      local h1 = (seed and seed + 0ULL) or 0ULL
      local data = ffi.cast(uint8_ptr_t, data)

      if nblocks > 0 then
         for i = 0, nblocks-1 do
            local k1 = ffi.cast(uint32_ptr_t, data)[i]
            k1 = band(k1*c1, max32)
            k1 = bxor(lshift(k1, 15), rshift(k1, 17))
            k1 = band(k1*c2, max32)
            h1 = bxor(h1, k1)
            h1 = bxor(lshift(h1, 13), rshift(h1, 19))
            h1 = band(h1*5 + c5, max32)
         end
      end

      local l = band(length, 3)
      if l > 0 then
         local k1 = 0ULL
         tail[0] = ffi.cast(uint32_ptr_t, data + lshift(nblocks, 2))[0]
         k1 = band(tail[0], rshift(0x00FFFFFF, (3-l)*8)) 
         k1 = band(k1*c1, max32)
         k1 = bxor(lshift(k1, 15), rshift(k1, 17))
         k1 = band(k1*c2, max32)
         h1 = bxor(h1, k1)
      end

      h1 = bxor(h1, length+0ULL)
      h1 = bxor(h1, rshift(h1, 16))
      h1 = band(h1*c3, max32)
      h1 = bxor(h1, rshift(h1, 13))
      h1 = band(h1*c4, max32)
      h1 = bxor(h1, rshift(h1, 16))
      self.h.u32[0] = band(h1, max32)
      return self.h
   end
end

do
   murmur.MurmurHash3_x64_128 = subClass(base_hash)
   local MurmurHash3_x64_128 = murmur.MurmurHash3_x64_128
   MurmurHash3_x64_128._name = 'MurmurHash3_x64_128'
   MurmurHash3_x64_128._size = 128

   local c1 = 0x87c37b91114253d5ULL
   local c2 = 0x4cf5ad432745937fULL
   local c3 = 0xff51afd7ed558ccdULL
   local c4 = 0xc4ceb9fe1a85ec53ULL
   local c5 = 0x52dce729ULL
   local c6 = 0x38495ab5ULL

   local taill = ffi.new("uint64_t[1]")
   local tailh = ffi.new("uint64_t[1]")

   local masks = {}
   for i = 1, 15 do
      masks[i] = rshift(0xFFFFFFFFFFFFFFFFULL, band(16-i, 7)*8)
   end

   function MurmurHash3_x64_128:hash (data, length, seed)
      local nblocks = rshift(length, 4)
      local h1 = (seed and seed+0ULL) or 0ULL
      local h2 = h1
      local data = ffi.cast(uint8_ptr_t, data)

      if nblocks > 0 then
         for i = 0, nblocks - 1 do
            local k1 = ffi.cast(uint64_ptr_t, data)[i*2]*c1
            k1 = bxor(lshift(k1, 31), rshift(k1, 33))
            k1 = k1*c2
            h1 = bxor(h1, k1)
            h1 = bxor(lshift(h1, 27), rshift(h1, 37))
            h1 = h1 + h2
            h1 = h1*5ULL + c5

            local k2 = ffi.cast(uint64_ptr_t, data)[i*2+1]*c2
            k2 = bxor(lshift(k2, 33), rshift(k2, 31))
            k2 = k2*c1
            h2 = bxor(h2, k2)
            h2 = bxor(lshift(h2, 31), rshift(h2, 33))
            h2 = h2 + h1
            h2 = h2*5ULL + c6
         end
      end

      data = data + lshift(nblocks, 4)
      local l = band(length, 15)
      if l > 8 then
         local k2 = 0ULL
         tailh[0] = ffi.cast(uint64_ptr_t, data+8)[0]
         k2 = band(tailh[0], masks[l])
         k2 = k2*c2
         k2 = bxor(lshift(k2, 33), rshift(k2, 31))
         k2 = k2*c1
         h2 = bxor(h2, k2)
         l = 8
      end

      if l > 0 then
         local k1 = 0ULL
         taill[0] = ffi.cast(uint64_ptr_t, data)[0]
         k1 = band(taill[0], masks[l])
         k1 = k1*c1
         k1 = bxor(lshift(k1, 31), rshift(k1, 33))
         k1 = k1*c2
         h1 = bxor(h1, k1)
      end

      h1 = bxor(h1, length+0ULL)
      h2 = bxor(h2, length+0ULL)
      h1 = h1+h2
      h2 = h2+h1

      -- fmix(h1)
      h1 = bxor(h1, rshift(h1, 33))*c3
      h1 = bxor(h1, rshift(h1, 33))*c4
      h1 = bxor(h1, rshift(h1, 33))

      -- fmix(h2)
      h2 = bxor(h2, rshift(h2, 33))*c3
      h2 = bxor(h2, rshift(h2, 33))*c4
      h2 = bxor(h2, rshift(h2, 33))

      h1 = h1+h2
      h2 = h2+h1
      self.h.u64[0] = h1
      self.h.u64[1] = h2
      return self.h
   end
end

local function selftest_hash (hash, expected, perf)
   local hash = hash:new()
   local bytes = hash:size()/8
   local key = ffi.new("uint8_t [256]")
   local hashes = ffi.new("uint8_t[?]", bytes*256)
   local seed = ffi.new("uint64_t")

   print("Sleftest hash "..hash:name())
   for i = 0, 255 do
      key[i] = i
      seed = 256-i
      hash:hash(key, i, seed)
      ffi.copy(hashes+i*bytes, hash.h, bytes)
   end
   local check = hash:hash(hashes, ffi.sizeof(hashes)).u32[0]
   if check == expected then
      print("Passed")
   else
      error("Failed, expected 0x"..bit.tohex(expected)..", got 0x"..bit.tohex(check))
   end

   if perf_enable and perf then
      print("Performance test with data blocks from "..(perf.min or 1).." to "
            ..perf.max.." bytes (iterations per second)")
      assert(perf.max < 1024)
      local v = ffi.new("uint8_t[1024]")

      for j = perf.min or 1, perf.max do
         jit.flush()
         local start = ffi.C.get_time_ns()
         for i = 1, perf.iter do
            hash:hash(v, j, 0)
         end
         local stop = ffi.C.get_time_ns()
         local iter_rate = perf.iter/(tonumber(stop-start)/1e9)
         print(j, math.floor(iter_rate))
         assert(iter_rate >= perf.expect, string.format("Performance test failed "
                  .."for %d byte blocks, "
                  .."expected at least %d "
                  .." iterations per second, "
                  .."got %d", j, perf.expect, iter_rate))
         end
         print("Passed")
      end
   end

function selftest()
   selftest_hash(murmur.MurmurHash3_x86_32, 0xB0F57EE3, { max = 8, iter = 1e7, expect = 1e7 })
   selftest_hash(murmur.MurmurHash3_x64_128, 0x6384BA69, { max = 32, iter = 1e7, expect = 4*1e7 })
end

murmur.selftest = selftest

return murmur
