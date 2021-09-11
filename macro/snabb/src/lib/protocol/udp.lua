-- Use of this source code is governed by the Apache 2.0 license; see COPYING.

module(..., package.seeall)
local ffi = require("ffi")
local C = ffi.C
local header = require("lib.protocol.header")
local ipsum = require("lib.checksum").ipsum
local lib = require("core.lib")
local htons, ntohs = lib.htons, lib.ntohs

local udp = subClass(header)

-- Class variables
udp._name = "udp"
udp._ulp = { method = nil }
udp:init(
   {
      [1] = ffi.typeof[[
	    struct {
	       uint16_t    src_port;
	       uint16_t    dst_port;
	       uint16_t    len;
	       uint16_t    checksum;
	    } __attribute__((packed))
      ]],
   })

-- Class methods

function udp:new (config)
   local o = udp:superClass().new(self)
   o:src_port(config.src_port)
   o:dst_port(config.dst_port)
   o:length(8)
   o:header().checksum = 0
   return o
end

-- Instance methods

function udp:src_port (port)
   local h = self:header()
   if port ~= nil then
      h.src_port = htons(port)
   end
   return ntohs(h.src_port)
end

function udp:dst_port (port)
   local h = self:header()
   if port ~= nil then
      h.dst_port = htons(port)
   end
   return ntohs(h.dst_port)
end

function udp:length (len)
   local h = self:header()
   if len ~= nil then
      h.len = htons(len)
   end
   return ntohs(h.len)
end

function udp:checksum (payload, length, ip)
   local h = self:header()
   if payload then
      local csum = 0
      if ip then
         -- Checksum IP pseudo-header
         local ph = ip:pseudo_header(length + self:sizeof(), 17)
         csum = ipsum(ffi.cast("uint8_t *", ph), ffi.sizeof(ph), 0)
      end
      -- Add UDP header
      h.checksum = 0
      csum = ipsum(ffi.cast("uint8_t *", h),
                   self:sizeof(), bit.bnot(csum))
      -- Add UDP payload
      h.checksum = htons(ipsum(payload, length, bit.bnot(csum)))
   end
   return ntohs(h.checksum)
end

-- override the default equality method
function udp:eq (other)
   --compare significant fields
   return (self:src_port() == other:src_port()) and
         (self:dst_port() == other:dst_port()) and
         (self:length() == other:length())
end

return udp
