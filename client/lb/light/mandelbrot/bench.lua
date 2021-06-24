-- "I hereby put all Lua/LuaJIT tests and benchmarks that I wrote under the public domain." Mike Pall
-- https://github.com/LuaJIT/LuaJIT-test-cleanup
--local print, char, unpack = io.print_devnull, string.char, unpack

function run_iter(N)
  local M, ba, bb, buf = 2/N, 2^(N%8+1)-1, 2^(8-N%8), {}
  --print("P4\n", N, " ", N, "\n")
  local s
  for y=0,N-1 do
    local Ci, b, p = y*M-1, 1, 0
    for x=0,N-1 do
      local Cr = x*M-1.5
      local Zr, Zi, Zrq, Ziq = Cr, Ci, Cr*Cr, Ci*Ci
      b = b + b
      for i=1,49 do
        Zi = Zr*Zi*2 + Ci
        Zr = Zrq-Ziq + Cr
        Ziq = Zi*Zi
        Zrq = Zr*Zr
        if Zrq+Ziq > 4.0 then b = b + 1; break; end
      end
      if b >= 256 then p = p + 1; buf[p] = 511 - b; b = 1; end
    end
    if b ~= 1 then 
      p = p + 1; buf[p] = (ba-b)*bb; 
    end
    --print(buf)
  end
  return
end


run_iter(tonumber(io.read()))
