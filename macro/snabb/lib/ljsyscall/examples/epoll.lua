-- simple epoll-based socket example. Serves up http responses, but is of course not a proper server
-- you can test performance with ab -n 100000 -c 100 http://localhost:8000/ although ab may be the limiting factor

local S
if arg[1] == "rump" then
  S = require "syscall.rump.init".init{"net", "net.net", "net.local", "net.netinet"}
else
  S = require "syscall"
end

local t, c = S.t, S.c

local function assert(cond, s, ...)
  if cond == nil then error(tostring(s)) end -- annoyingly, assert does not call tostring!
  return cond, s, ...
end

local maxevents = 1024

local poll

local function nilf() return nil end

-- this is somewhat working toward a common API but needs a lot more work, but has resulted in some improvements
if S.epoll_create then
  poll = {
    init = function(this)
      return setmetatable({fd = assert(S.epoll_create())}, {__index = this})
    end,
    event = t.epoll_event(),
    add = function(this, s)
      local event = this.event
      event.events = c.EPOLL.IN
      event.data.fd = s:getfd()
      assert(this.fd:epoll_ctl("add", s, event))
    end,
    events = t.epoll_events(maxevents),
    get = function(this)
      local f, a, r = this.fd:epoll_wait(this.events)
      if not f then
        print("error on fd", a)
        return nilf
      else
        return f, a, r
      end
    end,
    eof = function(ev) return ev.HUP or ev.ERR or ev.RDHUP end,
  }
elseif S.kqueue then
  poll = {
    init = function(this)
      return setmetatable({fd = assert(S.kqueue())}, {__index = this})
    end,
    event = t.kevents(1),
    add = function(this, s)
      local event = this.event[1]
      event.fd = s
      event.setfilter = "read"
      event.setflags = "add"
      assert(this.fd:kevent(this.event, nil, 0))
    end,
    events = t.kevents(maxevents),
    get = function(this)
      local f, a, r = this.fd:kevent(nil, this.events)
      if not f then
        print("error on fd", a)
        return nilf
      else
        return f, a, r
      end
    end,
    eof = function(ev) return ev.EOF or ev.ERROR end,
  }
else
  error("no epoll or kqueue support")
end

local s = assert(S.socket("inet", "stream, nonblock"))

s:setsockopt("socket", "reuseaddr", true)

local sa = assert(t.sockaddr_in(8000, "127.0.0.1"))

assert(s:bind(sa))

assert(s:listen(128))

local ep = poll:init()

ep:add(s)

local w = {}

local msg = [[
<html>
<head>
<title>performance test</title>
</head>
<body>
test
</body>
</html>
]]

local reply = table.concat({
"HTTP/1.0 200 OK",
"Content-type: text/html",
"Connection: close",
"Content-Length: " .. #msg,
"",
"",
}, "\r\n") .. msg


local bufsize = 4096
local buffer = t.buffer(bufsize)

local ss = t.sockaddr_storage()

local function loop()

for i, ev in ep:get() do

  if ep.eof(ev) then
    ev.fd:close()
    w[ev.fd] = nil
  end

  if ev.fd == s:getfd() then -- server socket, accept
    repeat
      local a, err = s:accept(ss, nil, "nonblock")
      if a then
        ep:add(a)
        w[a:getfd()] = a
      end
    until not a
  else
    local fd = w[ev.fd]
    fd:read(buffer, bufsize)
    local n = fd:write(reply)
    assert(n == #reply)
    assert(fd:close())
    w[ev.fd] = nil
  end
end

return loop()

end

loop()


