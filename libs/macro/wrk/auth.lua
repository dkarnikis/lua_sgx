local auth = {}

auth.exec = function(dat)
    local obj = dkjson.decode(dat)
    -- get the values 
    obj.w[1].format = wrk.format
    -- perform the critical code here
    local res = obj.w[1].format("GET", obj.p)
    -- end of critical code
    -- remove any references to function entities
    obj.w[1].format = nil
    -- encode the data
    result = {r = res, wr = obj.w}
    -- print to stdout so the client can parse them
    return dkjson.encode(result)
end

auth.exec2 = function(dat)
    local obj = dkjson.decode(dat)
    status = obj.s
    headers = obj.h
    body = obj.b
    token = obj.t
    path = obj.p
    if not token and status == 200 then
        token = headers["X-Token"]
        path = "/resource"
        headers["X-Token"] = token
    end
    result = {t = token, p = path, h = {headers}}
    return dkjson.encode(result)
end

return auth
