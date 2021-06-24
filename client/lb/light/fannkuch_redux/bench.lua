-- The Computer Language Benchmarks Game
-- http://shootout.alioth.debian.org/
-- contributed by Mike Pall

local EXPECT_CKSUM = 1616
local MAX_N = 8

function run_iter(n)
  for i=1,n do
    inner_iter()
  end
end

function inner_iter()
  n = MAX_N
  local p, q, s, sign, maxflips, sum = {}, {}, {}, 1, 0, 0
  for i=1,n do p[i] = i; q[i] = i; s[i] = i end
  repeat
    -- Copy and flip.
    local q1 = p[1]				-- Cache 1st element.
    if q1 ~= 1 then
      for i=2,n do q[i] = p[i] end		-- Work on a copy.
      local flips = 1
      repeat
	local qq = q[q1]
	if qq == 1 then				-- ... until 1st element is 1.
	  sum = sum + sign*flips
	  if flips > maxflips then maxflips = flips end -- New maximum?
	  break
	end
	q[q1] = q1
	if q1 >= 4 then
	  local i, j = 2, q1 - 1
	  repeat q[i], q[j] = q[j], q[i]; i = i + 1; j = j - 1; until i >= j
	end
	q1 = qq; flips = flips + 1
      until false
    end
    -- Permute.
    if sign == 1 then
      p[2], p[1] = p[1], p[2]; sign = -1	-- Rotate 1<-2.
    else
      p[2], p[3] = p[3], p[2]; sign = 1		-- Rotate 1<-2 and 1<-2<-3.
      for i=3,n do
	local sx = s[i]
	if sx ~= 1 then s[i] = sx-1; break end
	if i == n then
          if sum ~= EXPECT_CKSUM then
            print("bad checksum: " .. sum .. " vs " .. EXPECT_CKSUM)
            os.exit(1)
          end
          return sum, maxflips
        end	-- Out of permutations.
	s[i] = i
	-- Rotate 1<-...<-i+1.
	local t = p[1]; for j=1,i do p[j] = p[j+1] end; p[i+1] = t
      end
    end
  until false
end

run_iter(tonumber(io.read()))


