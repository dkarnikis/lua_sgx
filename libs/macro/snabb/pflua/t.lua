local match = require("match")
local json = require("dkjson")
function dump(o)
	if type(o) == 'table' then
		local s = '{ '
		for k,v in pairs(o) do
			if type(k) ~= 'number' then k = '"'..k..'"' end
			s = s .. '['..k..'] = ' .. dump(v) .. ','
		end
		return s .. '} '
	else
		return tostring(o)
	end
end

accepted = 0
dropped = 0
rejected = 0
--
--function reject()
--	rejected = rejected + 1
--end
--
--
--
--function accept()
--	accepted = accepted + 1
--end
--
--
--function drop()
--	dropped = dropped + 1
--end

self = {}
--self.drop = drop

--self.drop = drop
--self.accept = accept
--self.reject = reject
self.handler_map = {}

f=io.open("out", "r")
a=f:read("*a")
local rules = { BITTORRENT = [[match {dst net 10.10.10.22 => drop;
otherwise => accept }]]}


str = string.rep("a", 10240)


f:close()
x=json.decode(a)
for k, v in pairs(x) do
	a = v
	--c_str = ffi.new("unsigned char[10240]", a.l)

	--ffi.copy(c_str, a.data)
	--print(ffi.string(c_str))
	--a.data = c_str
	policy1=rules
	local policy=policy1[a.name] or policy1["default"]
	if policy == "accept" then
		accepted = accepted + 1
	elseif policy == "drop" then
		dropped = dropped + 1
	elseif policy == "reject" then
		rejected = rejected + 1
	elseif type(policy) == "string" then
		local obj1 = { accept = function (self, pkt, len)
			accepted = accepted + 1
		end,
		drop = function(self, pkt, len) 
			dropped = dropped + 1
		end,
		reject = function(self, pkt, len)
			rejected = rejected + 1
		end,
		match = match.compile(policy, opts)
	}
	obj1:match(a.data ,a.l,a.fl)
	--			if self.handler_map[policy] then
	--				-- we've already compiled a matcher for this policy
	--				self.handler_map[policy](self, a.data, a.l, a.fl)
	--			else
	--				handler = match.compile(policy, opts)
	--				self.handler_map[policy] = handler
	--				handler(self, a.data, a.l, a.fl)
	--			end
else
	accepted = accepted + 1
	--match.ac = match.ac + 1 --dropped = dropped + 1
end
	end
	print("DONE")
	res = {}
	res.a = accepted
	res.d = dropped
	res.r = rejected
	print(json.encode(res, {indent = true}))
