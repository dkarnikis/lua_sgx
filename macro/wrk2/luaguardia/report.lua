package.path = package.path .. ";../../libs/macro/wrk/?.lua"
package.path = package.path .. ";../../libs/?.lua"

lua_client = require("lclient")
lua_client.bootstrap()

report = require("report")
report = wrapper(report)

done = function(summary, latency, requests)
    lua_client.connect_to_worker(lua_client.mode)
    lua_client.set_module_file(nil)
    -- send the module info to the client
    lua_client.send_modules(lua_client.get_config()[1])
    local a = {n = {}, p = {}}
    local i = 0
    for _, p in pairs({ 50, 90, 99, 99.999 }) do
        n = latency:percentile(p)
        a.n[i] = n
        a.p[i] = p
        i = i + 1
    end
    local dat = dkjson.encode(a)
    local res = report.exec(dat)
    print(res)
    lua_client.close_worker(lua_client.get_config()[1].socket)
    io.write(string.format("requests: %d,\n", summary.requests))
    io.write(string.format("duration_in_microseconds: %0.2f,\n", summary.duration))
    io.write(string.format("bytes: %d\n", summary.bytes))
    io.write(string.format("requests_per_sec: %0.2f\n", (summary.requests/summary.duration)*1e6))
    io.write(string.format("bytes_transfer_per_sec: %0.2f\n", (summary.bytes/summary.duration)*1e6))
end
