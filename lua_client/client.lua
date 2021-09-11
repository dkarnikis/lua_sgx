local client = require("lclient")
--for k,v in pairs(client) do
--    _G[k] = client[k]
--end

client.bootstrap()
for k,v in pairs(client) do
    _G[k] = client[k]
end
client.run_code()
