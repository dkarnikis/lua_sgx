package.path = package.path .. ";../../libs/macro/wrk/?.lua"
package.path = package.path .. ";../../libs/?.lua"
report = require("report")
report = wrapper(report)

done = function(summary, latency, requests)
    connect_to_worker(mode)
    module_file_name = nil
    -- send the module info to the client
    send_modules(config[1])
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
    close_worker(config[1].socket)
    io.write(string.format("requests: %d,\n", summary.requests))
    io.write(string.format("duration_in_microseconds: %0.2f,\n", summary.duration))
    io.write(string.format("bytes: %d\n", summary.bytes))
    io.write(string.format("requests_per_sec: %0.2f\n", (summary.requests/summary.duration)*1e6))
    io.write(string.format("bytes_transfer_per_sec: %0.2f\n", (summary.bytes/summary.duration)*1e6))
end
