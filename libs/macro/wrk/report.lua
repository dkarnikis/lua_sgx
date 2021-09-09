local report = {} 

report.exec = function(dat)
    local result = ''
    local obj = dkjson.decode(dat)
    result = result .."------------------------------\n"
    local i = 0
    for _, p in pairs({ 50, 90, 99, 99.999 }) do
        n = obj.n[tostring(i)] --latency:percentile(p)
        result = result .. string.format("%g%%,%d\n", tonumber(obj.p[tostring(i)]), tonumber(n))
        i = i + 1
    end
    result = result .."------------------------------\n"
    return result
end

return report
