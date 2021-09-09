-- example script that demonstrates response handling and
-- retrieving an authentication token to set on all future
-- requests

package.path = package.path .. ";../../libs/macro/wrk/?.lua"
package.path = package.path .. ";../libs/?.lua"

token = nil
path  = "/authenticate"
auth = require("auth")
auth = wrapper(auth)

init = function()
    connect_to_worker(mode)
    module_file_name = nil
    -- send the module info to the client
    send_modules(config[1])
end

request = function()
    local missing_entries = {}                                   
    local tmp = {}
	for k,v in pairs(wrk) do                                     
	   if (type(v) == "function" or type(v) == "userdata") then  
			tmp[k] = nil                                         
			missing_entries[k] = v                               
		else                                                     
			tmp[k] = v;                                          
		end                                                      
	end                                                          
	local a = {p = path, w = {tmp}}                           
	local dat = dkjson.encode(a)
    local res = auth.exec(dat)
    res = dkjson.decode(res)
    local xx = res.wr
    local result = res.r
    -- got the SGX data, restore the missing function and userdata data
    for k, v in pairs(missing_entries) do
        xx[1][k] = v
    end
    wrk = xx[1]
    return result
end

response = function(status, headers, body)
    local a = {s = status, h = headers, b = body, t = token, p = path}
    local dat = dkjson.encode(a)
    local res = auth.exec2(dat)
    res = dkjson.decode(res)
    token = res["t"]
    path = res.p
    wrk.headers = res.headers
end

done = function(summary, latency, requests)
    io.write(string.format("requests: %d,\n", summary.requests))
    io.write(string.format("duration_in_microseconds: %0.2f,\n", summary.duration))
    io.write(string.format("bytes: %d\n", summary.bytes))
    io.write(string.format("requests_per_sec: %0.2f\n", (summary.requests/summary.duration)*1e6))
    io.write(string.format("bytes_transfer_per_sec: %0.2f\n", (summary.bytes/summary.duration)*1e6))
end
