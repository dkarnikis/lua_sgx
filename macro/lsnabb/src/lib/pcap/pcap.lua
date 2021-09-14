-- Use of this source code is governed by the Apache 2.0 license; see COPYING.

module(...,package.seeall)

local ffi = require("ffi")

-- PCAP file format: http://wiki.wireshark.org/Development/LibpcapFileFormat/
local pcap_file_t = ffi.typeof[[
struct {
    /* file header */
    uint32_t magic_number;   /* magic number */
    uint16_t version_major;  /* major version number */
    uint16_t version_minor;  /* minor version number */
    int32_t  thiszone;       /* GMT to local correction */
    uint32_t sigfigs;        /* accuracy of timestamps */
    uint32_t snaplen;        /* max length of captured packets, in octets */
    uint32_t network;        /* data link type */
}
]]

local pcap_record_t = ffi.typeof[[
struct {
    /* record header */
    uint32_t ts_sec;         /* timestamp seconds */
    uint32_t ts_usec;        /* timestamp microseconds */
    uint32_t incl_len;       /* number of octets of packet saved in file */
    uint32_t orig_len;       /* actual length of packet */
}
]]

function write_file_header (file)
   local pcap_file = ffi.new(pcap_file_t)
   pcap_file.magic_number = 0xa1b2c3d4
   pcap_file.version_major = 2
   pcap_file.version_minor = 4
   pcap_file.snaplen = 65535
   pcap_file.network = 1
   file:write(ffi.string(pcap_file, ffi.sizeof(pcap_file)))
   file:flush()
end

function write_record (file, ffi_buffer, length)
   write_record_header(file, length)
   file:write(ffi.string(ffi_buffer, length))
   file:flush()
end

function write_record_header (file, length)
   local pcap_record = ffi.new(pcap_record_t)
   pcap_record.incl_len = length
   pcap_record.orig_len = length
   file:write(ffi.string(pcap_record, ffi.sizeof(pcap_record)))
end

function read_file_header (file)
   local pcap_file = readc(file, pcap_file_t)
   if pcap_file.magic_number == 0xD4C3B2A1 then
      error("Endian mismatch in " .. filename)
   elseif pcap_file.magic_number ~= 0xA1B2C3D4 then
      error("Bad PCAP magic number in " .. filename)
   end
   return pcap_file
end

-- Return an iterator for pcap records in FILENAME.
function records (filename)
   local file = io.open(filename, "r")
   if file == nil then error("Unable to open file: " .. filename) end
   read_file_header(file)
   local function pcap_records_it (t, i)
      local record = readc(file, pcap_record_t)
      if record == nil then return nil end
      local datalen = math.min(record.orig_len, record.incl_len)
      local packet = file:read(datalen)
      return packet, record
   end
   return pcap_records_it, true, true
end

-- Read a C object of TYPE from FILE
function readc(file, type)
   local string = file:read(ffi.sizeof(type))
   if string == nil then return nil end
   if #string ~= ffi.sizeof(type) then
      error("short read of " .. type .. " from " .. tostring(file))
   end
   local obj = ffi.new(type)
   ffi.copy(obj, string, ffi.sizeof(type))
   return obj
end
