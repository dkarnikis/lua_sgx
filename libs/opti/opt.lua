local opt = {}
-- print
function opt.t_print(num)
    local i
    for i=0, num do
        io.write('x')
    end
end

-- reads
function newArray(size)
    local t = {}
    local i
    for i = 1, size do
        t[i] = i
    end
    return t
end

function opt.reads(size)
    local t = newArray(size)
    -- random seed
    math.randomseed(os.clock()*100000000000)
    local b = 0
    -- generate random number
    for i = 1, 1000000 do
        local a = math.random(0, size)
        local b = t[a]
    end
end

-- writes
function opt.writes(size)
    local t = newArray(size)
    local i
    -- random seed
    math.randomseed(os.clock()*100000000000)
    -- generate random number
    for i = 1, 1000000 do
        local a = math.random(0, size)
        t[a] = 'x'
    end
end

-- fread
function opt.fread(read_size)                
    local fname="out"                      
    local file=io.open(fname, "r")         

    while true do                          
        local buffer = file:read(read_size)
        if buffer == nil then              
            break                          
        end                                
    end                                    
end

return opt
