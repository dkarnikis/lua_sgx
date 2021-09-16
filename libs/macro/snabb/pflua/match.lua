local utils = require('utils')
local parse_pflang = require('parse').parse
local expand_pflang = require('expand').expand
local optimize = require('optimize')
local anf = require('anf')
local ssa = require('ssa')
local backend = require('backend')

match = {}
match.__index = match

---- called by pfmatch handler, handle rejection response
--function reject(pkt, len)
--	link.transmit(self.output.reject, self:make_reject_response())
--	self.rejected = self.rejected + 1
--
--	if self.logging == "on" then
--		self:log_packet("REJECT")
--	end
--
--	packet.free(self.current_packet)
--end
--
---- called by pfmatch handler, forward packet
--function accept(pkt, len)
--	link.transmit(self.output.output, self.current_packet)
--	self.accepted = self.accepted + 1
--end
--


local function split(str, pat)
	pat = '()'..pat..'()'
	local ret, start_pos = {}, 1
	local tok_pos, end_pos = str:match(pat)
	while tok_pos do
		table.insert(ret, str:sub(start_pos, tok_pos - 1))
		start_pos = end_pos
		tok_pos, end_pos = str:match(pat, start_pos)
	end
	table.insert(ret, str:sub(start_pos))
	return ret
end

local function remove_comments(str)
	local lines = split(str, '\n')
	for i=1,#lines do
		local line = lines[i]
		local comment = line:match('()%-%-')
		if comment then lines[i] = line:sub(1, comment - 1) end
	end
	return table.concat(lines, '\n')
end

-- Return line, line number, column number.
local function error_location(str, pos)
	local start, count = 1, 1
	local stop = str:match('()\n', start)
	while stop and stop < pos do
		start, stop = stop + 1, str:match('()\n', stop + 1)
		count = count + 1
	end
	if stop then stop = stop - 1 end
	return str:sub(start, stop), count, pos - start + 1
end

local function scanner(str)
	str = remove_comments(str)
	local pos = 1
	local function error_str(message, ...)
		local line, line_number, column_number = error_location(str, pos)
		local message = "\npfmatch: syntax error:%d:%d: "..message..'\n'
		local result = message:format(line_number, column_number, ...)
		result = result..line.."\n"
		result = result..string.rep(" ", column_number-1).."^".."\n"
		return result
	end
	local primitive_error = error
	local function error(message, ...)
		primitive_error(error_str(message, ...))
	end

	local function skip_whitespace()
		pos = str:match('^%s*()', pos)
	end
	local function peek(pat)
		skip_whitespace()
		return str:match('^'..pat, pos)
	end
	local function check(pat)
		skip_whitespace()
		local start_pos, end_pos = pos, peek(pat.."()")
		if not end_pos then return nil end
		pos = end_pos
		return str:sub(start_pos, end_pos - 1)
	end
	local function next_identifier()
		local id = check('[%a_][%w_]*')
		if not id then error('expected an identifier') end
		return id
	end
	local function next_balanced(pair)
		local tok = check('%b'..pair)
		if not tok then error("expected balanced '%s'", pair) end
		return tok:sub(2, #tok - 1)
	end
	local function consume(pat)
		if not check(pat) then error("expected pattern '%s'", pat) end
	end
	local function consume_until(pat)
		skip_whitespace()
		local start_pos, end_pos, next_pos = pos, str:match("()"..pat.."()", pos)
		if not next_pos then error("expected pattern '%s'") end
		pos = next_pos
		return str:sub(start_pos, end_pos - 1)
	end
	local function done()
		skip_whitespace()
		return pos == #str + 1
	end
	return {
		error = error,
		peek = peek,
		check = check,
		next_identifier = next_identifier,
		next_balanced = next_balanced,
		consume = consume,
		consume_until = consume_until,
		done = done
	}
end

local parse_dispatch

local function parse_call(scanner)
	local proc = scanner.next_identifier()
	if not proc then scanner.error('expected a procedure call') end
	local result = { 'call', proc }
	if scanner.peek('%(') then
		local args_str = scanner.next_balanced('()')
		if not args_str:match('^%s*$') then
			local args = split(args_str, ',')
			for i=1,#args do
				table.insert(result, parse_pflang(args[i], {arithmetic=true}))
			end
		end
	end
	return result
end

local function parse_cond(scanner)
	local res = { 'cond' }
	while not scanner.check('}') do
		local test
		if scanner.check('otherwise') then
			test = { 'true' }
			scanner.consume('=>')
		else
			test = parse_pflang(scanner.consume_until('=>'))
		end
		local consequent = parse_dispatch(scanner)
		scanner.check('[,;]')
		table.insert(res, { test, consequent })
	end
	return res
end

function parse_dispatch(scanner)
	if scanner.check('{') then return parse_cond(scanner) end
	return parse_call(scanner)
end

local function subst(str, values)
	local out, pos = '', 1
	while true do
		local before, after = str:match('()%$[%w_]+()', pos)
		if not before then return out..str:sub(pos) end
		out = out..str:sub(pos, before - 1)
		local var = str:sub(before + 1, after - 1)
		local val = values[var]
		if not val then error('var not found: '..var) end
		out = out..val
		pos = after
	end
	return out
end

local function parse(str)
	local scanner = scanner(str)
	scanner.consume('match')
	scanner.consume('{')
	local cond = parse_cond(scanner)
	if not scanner.done() then scanner.error("unexpected token") end
	return cond
end

local function expand_arg(arg, dlt)
	-- The argument is an arithmetic expression, but the pflang expander
	-- expects a logical expression.  Wrap in a dummy comparison, then
	-- tease apart the conditions and the arithmetic expression.
	local expr = expand_pflang({ '=', arg, 0 }, dlt)
	local conditions = {}
	while expr[1] == 'if' do
		table.insert(conditions, expr[2])
		assert(type(expr[4]) == 'table')
		assert(expr[4][1] == 'fail' or expr[4][1] == 'false')
		expr = expr[3]
	end
	assert(expr[1] == '=' and expr[3] == 0)
	return conditions, expr[2]
end

local function expand_call(expr, dlt)
	local conditions = {}
	local res = { expr[1], expr[2] }
	for i=3,#expr do
		local arg_conditions, arg = expand_arg(expr[i], dlt)
		conditions = utils.concat(conditions, arg_conditions)
		table.insert(res, arg)
	end
	local test = { 'true' }
	-- Preserve left-to-right order of conditions.
	while #conditions ~= 0 do
		test = { 'if', table.remove(conditions), test, { 'false' } }
	end
	return test, res
end

local expand_cond

-- Unlike pflang, out-of-bounds and such just cause the clause to fail,
-- not the whole program.
local function replace_fail(expr)
	if type(expr) ~= 'table' then return expr
	elseif expr[1] == 'fail' then return { 'false' }
	elseif expr[1] == 'if' then
		local test = replace_fail(expr[2])
		local consequent = replace_fail(expr[3])
		local alternate = replace_fail(expr[4])
		return { 'if', test, consequent, alternate }
	else
		return expr
	end
end

local function expand_clause(test, consequent, dlt)
	test = replace_fail(expand_pflang(test, dlt))
	if consequent[1] == 'call' then
		local conditions, call = expand_call(consequent, dlt)
		return { 'if', test, conditions, { 'false' } }, call
	else
		assert(consequent[1] == 'cond')
		return test, expand_cond(consequent, dlt)
	end
end

function expand_cond(expr, dlt)
	local res = { 'false' }
	for i=#expr,2,-1 do
		local clause = expr[i]
		local test, consequent = expand_clause(clause[1], clause[2], dlt)
		res = { 'if', test, consequent, res }
	end
	return res
end

local function expand(expr, dlt)
	return expand_cond(expr, dlt)
end


local compile_defaults = {
	dlt='EN10MB', optimize=true, source=false, subst=false, extra_args={flow_count}
}

function compile(str, opts)

	opts = utils.parse_opts(opts or {}, compile_defaults)
	if opts.subst then str = subst(str, opts.subst) end

	-- if the compiled function should have extra formal parameters, then
	-- pass them to the various passes through filter_args
	local extra_args = {}
	for _,v in ipairs(opts.extra_args) do
		utils.filter_args[v] = true
	end

	local expr = expand(parse(str), opts.dlt)
	if opts.optimize then 
		expr = optimize.optimize(expr)
	end
	expr = anf.convert_anf(expr)
	expr = ssa.convert_ssa(expr)
	if opts.source then 
		return backend.emit_match_lua(expr, unpack(opts.extra_args)) end
		return backend.emit_and_load_match(expr, str, table.unpack(opts.extra_args))
	end

	function selftest()
		print("selftest: pf.match")
		local function test(str, expr)
			utils.assert_equals(expr, parse(str))
		end
		test("match {}", { 'cond' })
		test("match--comment\n{}", { 'cond' })
		test(" match \n     {  }   ", { 'cond' })
		test("match{}", { 'cond' })
		test("match { otherwise => x() }",
		{ 'cond', { { 'true' }, { 'call', 'x' } } })
		test("match { otherwise => x(1) }",
		{ 'cond', { { 'true' }, { 'call', 'x', 1 } } })
		test("match { otherwise => x(1&1) }",
		{ 'cond', { { 'true' }, { 'call', 'x', { '&', 1, 1 } } } })
		test("match { otherwise => x(ip[42]) }",
		{ 'cond', { { 'true' }, { 'call', 'x', { '[ip]', 42, 1 } } } })
		test("match { otherwise => x(ip[42], 10) }",
		{ 'cond', { { 'true' }, { 'call', 'x', { '[ip]', 42, 1 }, 10 } } })
		test(subst("match { otherwise => x(ip[$loc], 10) }", {loc=42}),
		{ 'cond', { { 'true' }, { 'call', 'x', { '[ip]', 42, 1 }, 10 } } })

		local function test(str, expr)
			utils.assert_equals(expr, expand(parse(str), 'EN10MB'))
		end
		test("match { otherwise => x() }",
		{ 'if', { 'if', { 'true' }, { 'true' }, { 'false' } },
		{ 'call', 'x' },
		{ 'false' } })
		test("match { otherwise => x(1) }",
		{ 'if', { 'if', { 'true' }, { 'true' }, { 'false' } },
		{ 'call', 'x', 1 },
		{ 'false' } })
		test("match { otherwise => x(1/0) }",
		{ 'if', { 'if', { 'true' },
		{ 'if', { '!=', 0, 0 }, { 'true' }, { 'false' } },
		{ 'false' } },
		{ 'call', 'x', { 'uint32', { '/', 1, 0 } } },
		{ 'false' } })

		local function test(str, expr)
			utils.assert_equals(expr, optimize.optimize(expand(parse(str), 'EN10MB')))
		end
		test("match { otherwise => x() }",
		{ 'call', 'x' })
		test("match { otherwise => x(1) }",
		{ 'call', 'x', 1 })
		test("match { otherwise => x(1/0) }",
		{ 'fail' })

		local function test(str)
			-- Just a test to see if it works without errors.
			compile(str)
		end



		test("match { tcp port 80 => pass }")

		local function test(str, pkt, obj)
			-- Try calling the matching method on the given table
			-- which should have handlers installed
			obj.match = compile(str)
			print(obj:match(pkt.packet, pkt.len))
		end

		--local savefile = require("savefile")
		--pkts = savefile.load_packets("arp.pcap")
		local policy = "match { dst net 10.10.10.22  => drop;otherwise => pass }"
		test(policy,
		pkts[1],
		-- the handler shouldn't be called
		{ pass = function (self, pkt, len)  end })
		test("match { arp => handle(&arp[1:1]) }",
		pkts[1],
		{ handle = function (self, pkt, len, off)
			utils.assert(self ~= nil)
			utils.assert(pkt ~= nil)
			utils.assert(len ~= nil)
			utils.assert_equals(off, 15)
		end })

		print("OK")

	end
	local function test(str, pkt, obj)
		-- Try calling the matching method on the given table
		-- which should have handlers installed
		obj.match = compile(str, opts)
		obj:match(pkt.packet, pkt.len)
	end

	function utf8_from(t)
		local bytearr = {}
		for _, v in ipairs(t) do
			local utf8byte = v < 0 and (0xff + v + 1) or v
			table.insert(bytearr, string.char(utf8byte))
		end
		return table.concat(bytearr)
	end



-- called by pfmatch handlers, just drop the packet on the floor
function drop(pkt, len)
	--packet.free(self.current_packet)
	--self.dropped = self.dropped + 1
    _G.accepted = 0
    _G.rejected = 0
	_G.dropped = 1
end

function accept(pkt, len)
	_G.accepted = 1
    _G.rejected = 0
    _G.dropped = 0
	--packet.free(self.current_packet)
end

function reject(pkt, len)
    _G.accepted = 0
    _G.dropped = 0
	_G.rejected = 1
	--packet.free(self.current_packet)
end

return {
    compile = compile,
    drop = drop,
	accept = accept,
    reject = reject,
}
