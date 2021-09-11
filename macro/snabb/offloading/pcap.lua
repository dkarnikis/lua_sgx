--module(...,package.seeall)
local pcap ={}
SGXReader = {}
function SGXReader:new(f)
end

function SGXReader:pull()
end

SGXWriter = {}
function SGXWriter:new(f)
end

function SGXReader:push()
end

return {
    SGXReader = SGXReader,
    SGXWriter = SGXWriter
}
