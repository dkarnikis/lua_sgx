local vpn = {}

test_aead_encrypt = function (plain)
    local key, nonce, aad, iv, const, encr, res, tag
    key = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    nonce = "\x00\x00\x00\x00\x00\x01\x02\x03\x04\x05\x06\x07"
    key = aead.poly_keygen(key, nonce)

    aad = "mallory"
    iv = "\x40\x41\x42\x43\x44\x45\x46\x47"
    const = "\x07\x00\x00\x00"
    aad = nil
    tag = nil
    if mode == 1 then
        encr, tag = aead.encrypt(aad, key, iv, const, plain)
        return encr
    else
        res = aead.decrypt(aad, key, iv, const, plain, tag)
        return res
    end
end

vpn.exec = function(opt)
	-- decode the weird characters
    local plain = dec(opt.data)
    local mode = opt.mode
    local res = ''
    if mode == "1" then
        res = test_aead_encrypt(plain, 1)
    else
        res = test_aead_encrypt(plain, 0)
    end
	-- encrypt the weird characters with base64
    return enc(res)
end


local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/' -- You will need this for encoding/decoding
-- encoding
function enc(data)
    return ((data:gsub('.', function(x) 
        local r,b='',x:byte()
        for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
        return r;
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c=0
        for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
        return b:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#data%3+1])
end

-- decoding
function dec(data)
    data = string.gsub(data, '[^'..b..'=]', '')
    return (data:gsub('.', function(x)
        if (x == '=') then return '' end
        local r,f='',(b:find(x)-1)
        for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
        return r;
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if (#x ~= 8) then return '' end
        local c=0
        for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
            return string.char(c)
    end))
end

return vpn
