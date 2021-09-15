local match = require("match")
local pflua = {}
self = {}
self.handler_map = {}

pflua.exec = function(dat)
    accepted = 0
    dropped = 0
    rejected = 0

    dat = base64.decode(dat)
    local x = dkjson.decode(dat)
    local rules = x.rules
    --rules = { BITTORRENT = [[match { flow_count >= 5 or dst net 10.10.10.22 => drop; otherwise => accept }]], default = "accept" }
    local policy = rules[x.name] or rules["default"]
    if policy == "accept" then
        accepted = accepted + 1
    elseif policy == "drop" then
        dropped = dropped + 1
    elseif policy == "reject" then
        rejected = rejected + 1
    elseif type(policy) == "string" then
        --    if self.handler_map[policy] then
        --        self.handler_map[policy](self, pkt, len, x.fl)
        --    else
        local opts = { extra_args = { "flow_count"}}
        --        local handler = match.compile(policy, opts)
        --        self.handler_map[policy] = handler
        --        --print(self, x.data, x.l, x.fl)
        --        handler(self, x.data, x.l, x.fl)
        --    end
        ---else
        ---    accepted = 2
        ---end
        local obj1 = {
            accept = function (self, pkt, len)
                accepted = 1
            end,
            drop = function(self, pkt, len) 
                dropped = 1
            end,
            reject = function(self, pkt, len)
                rejected = 1
            end,
            match = match.compile(policy, opts)
        }
        obj1:match(x.data ,x.l, x.fl)
    else
        print("XD")
        accepted = 1
        --match.ac = match.ac + 1 --dropped = dropped + 1
    end
    res = {}
    res.a=accepted
    res.d=dropped
    res.r=rejected
    return dkjson.encode(res)
end
return pflua
