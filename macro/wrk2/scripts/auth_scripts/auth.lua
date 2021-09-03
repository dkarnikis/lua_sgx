-- example script that demonstrates response handling and
-- retrieving an authentication token to set on all future
-- requests

token = nil
path  = "/authenticate"
json = require("scripts.dkjson")

request = function()
	-- dump the wrk data in the file 
    local f = io.open("out", 'w')
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
	f:write(json.encode(a, {indent = true}))                     
	f:close()                                                    
	-- trigger execution
    cmd="cp out scripts/auth_scripts/;./lua_vm -t -l scripts/auth_scripts/sgx_auth.lua > xd1;cat xd1"
    local h = io.popen(cmd)
    local res = json.decode(h:read("*a"))
    local xx = res.wr
    local result = res.r
    -- got the SGX data, restore the missing function and userdata data
    for k, v in pairs(missing_entries) do
        xx[1][k] = v
    end
    wrk = xx[1]
    h:close()
    return result
   --return wrk.format("GET", path)
end

response = function(status, headers, body)
    local a = {s = status, h = headers, b = body, t = token, p = path}
    f = io.open("out", 'w')
    f:write(json.encode(a, {indent=true}))
    f:close()
    cmd ="cp out scripts/;./lua_vm -l scripts/auth_scripts/sgx_auth2.lua > xd1; cat xd1"
    local h = io.popen(cmd)
    local res = json.decode(h:read("*a"))
    token = res["t"]
    path = res.p
    wrk.headers = res.headers
    h:close()
end
