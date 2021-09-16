local match = require("match")
_G.accept = match.accept
_G.drop = match.drop
_G.reject = match.reject

local pflua = {}
self = {}
self.handler_map = {}
self.handler_map.accept = _G.accept
self.accept = _G.accept
self.drop = _G.drop
self.reject = _G.reject
self.accepted = 0
self.rejected = 0
self.dropped = 0
self.flow_count = 0
    rules = { default = 'accept'}
    pflua.exec = function(dat)
        _G.accepted = 0
        -- in case an error happens, we drop
        _G.dropped = 1
        _G.rejected = 0
        dat = base64.decode(dat)
        local x = dkjson.decode(dat)
        local policy = rules[x.name] or rules["default"]
        if policy == "accept" then
            accepted = accepted + 1
        elseif policy == "drop" then
            dropped = dropped + 1
        elseif policy == "reject" then
            rejected = rejected + 1
        elseif type(policy) == "string" then
            local opts = { extra_args = { "flow_count"}}
            if self.handler_map[policy] then
                pcall(function()
                    --self.handler_map[policy](self, x.data, x.l, x.fl)
                    self.handler_map[policy](self, x.data, x.l, x.fl)
                end)
            else
                pcall(function()
                    local handler = match.compile(policy, opts)
                    self.handler_map[policy] = handler
                    handler(self, x.data, x.l, x.fl)end)
                end
            else
                _G.accepted = 1
            end
            res = {}
            res.a=_G.accepted
            res.d=_G.dropped
            res.r=_G.rejected
            return dkjson.encode(res)
        end
        return pflua
