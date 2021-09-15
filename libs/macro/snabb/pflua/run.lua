local match = require("match")
local json = require("dkjson")
accepted = 0
dropped = 0
rejected = 0
self = {}
self.handler_map = {}
f=io.open("out", "r")
a=f:read("*a")
local rules = { 
	[[match {dst net 0.0.0.0 			or
	dst net 0.0.0.02			or
	dst net 0.0.3.5			or
	dst net 0.1.0.30			or
	dst net 0.1.0.33			or
	dst net 0.1.0.35			or
	dst net 0.1.0.38			or
	dst net 0.1.1.1			or
	dst net 0.1.1.27			or
	dst net 0.1.1.31			or
	dst net 0.1.1.37			or
	dst net 0.1.2.5			or
	dst net 0.1.2.7			or
	dst net 0.1.2.8			or
	dst net 0.1.3.57			or
	dst net 0.1.4.5			or
	dst net 0.1.4.6			or
	dst net 0.1.4.8			or
	dst net 0.1.5.0			or
	dst net 0.1.5.1			or
	dst net 0.1.5.2			or
	dst net 0.1.5.3			or
	dst net 0.1.5.5			or
	dst net 0.1.5.6			or
	dst net 0.1.6.3			or
	dst net 0.1.8.6			or
	dst net 0.1.9.1			or
	dst net 0.2.0.5			or
	dst net 0.2.0.6			or
	dst net 0.2.1.17			or
	dst net 0.2.1.63			or
	dst net 0.2.2.69			or
	dst net 0.2.8.2			or
	dst net 0.3.1.73			or
	dst net 0.3.25.05			or
	dst net 0.30.5.121			or
	dst net 0.4.18.0			or
	dst net 0.5.0.0			or
	dst net 0.6.0.0			or
	dst net 0.60.10.00			or
	dst net 0.84.0.0			or
	dst net 0.9.0.181			or
	dst net 0.9.0.2			or
	dst net 0.9.0.5			or
	dst net 0.9.0.8			or
	dst net 0.9.1.1			or
	dst net 0.9.2.1			or
	dst net 0.9.2.219			or
	dst net 0.9.3.1			or
	dst net 0.9.5.1			or
	dst net 0.9.6.1			or
	dst net 0.9.8.1			or
	dst net 0.9.9.0			or
	dst net 0.99.0.53			or
	dst net 0.99.1.0			or
	dst net 0.99.1.1			or
	dst net 0.99.1.2			or
	dst net 0.99.1.3			or
	dst net 0.99.1.4			or
	dst net 0.99.2.0			or
	dst net 0.99.3.0			or
	dst net 0.99.4.2			or
	dst net 00.00.04.010			or
	dst net 000.0.1.77			or
	dst net 000.0.8.18			or
	dst net 000.0.8.21			or
	dst net 000.1.02.000			or
	dst net 000.1.4.11			or
	dst net 000.7.6.49			or
	dst net 001.0.7.10			or
	dst net 001.1.5.0			or
	dst net 002.3.1.21			or
	dst net 002.3.3.31			or
	dst net 002.3.4.16			or
	dst net 002.3.5.23			or
	dst net 002.8.0.0			or
	dst net 003.0.03.060			or
	dst net 003.3.7.22			or
	dst net 003.5.29.55			or
	dst net 003.5.31.58			or
	dst net 003.5.34.61			or
	dst net 003.5.38.66			or
	dst net 003.5.40.68			or
	dst net 005.134.22.125			or
	dst net 005.8.02.6			or
	dst net 006.07.25.05			or
	dst net 006.1.00.1			or
	dst net 99.9.5.15 =>accept; otherwise =>drop]]}
	local opts    = { extra_args = { "flow_count" } }
	f:close()
	for line in a:gmatch("([^\n]*)\n?") do
		a = json.decode(line)
		policy1=rules
		local policy=policy1[a.name] or policy1["default"]
		if a.name == "drop" then
			dropped = dropped + 1
		elseif policy == "accept" then
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
		obj1:match(a.data, a.l, a.fl)
		a = nil
		a.data = nil
		p = nil
	else
		accepted = accepted + 1
	end
end
res = {}
res.a = accepted
res.d = dropped
res.r = rejected
print(json.encode(res, {indent = true}))
collectgarbage()
