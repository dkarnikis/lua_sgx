local hook = {}

local run_local = false

local function offload (...)
    local args = table.pack(...)
    for i,v in ipairs(args) do
        print('-->' .. tostring(v) .. "\t")
    end 
end

function hook.wrapper (obj)
    if type(obj) == "function" then
        --hooked_functions[obj] = true
        return function(...)
            offload(...)
            if run_local == true then
                return obj(...)
            end
        end
    elseif type(obj) == "table" then
        for k,v in pairs(obj) do
            obj[k] = hook.wrapper(v)
        end 
    end
    return obj
end
--
--local test = {}
--test.foo = function (a) 
--    print(a)
--    return a 
--end
--test.lala = function (a) 
--    print(a + a)
--    return a + a
--end
--
--test = hook(test)
--print('----------------------------------------------')
--test.foo(1)
--test.lala(5)
--
return hook
