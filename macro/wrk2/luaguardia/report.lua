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
    local dat = dkjson.encode(a, {indent = false})
    local res = report.exec(dat)
    print(res)
    close_worker(config[1].socket)
end
