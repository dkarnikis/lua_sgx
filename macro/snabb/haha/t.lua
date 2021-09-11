local json = require("dkjson")
local aead = require "aead_chacha_poly"
local function test_aead_encrypt(plain)
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

function read_data()
    -- Opens a file in read mode
    file = io.open("out", "r")
    -- prints the first line of the file
    a = file:read("*a")
    -- closes the opened file
    file:close()
    return a
end

local plain = read_data()
-- read the mode 1 = encrypt, 0 = decrypt
mode = string.sub(plain, 1, 1)
-- remove the first character from string
plain = string.sub(plain, 2)
res = ""
if mode == 1 then
    res = test_aead_encrypt(plain, 1)
else
    res = test_aead_encrypt(plain, 0)
end

--local res = json.encode(test_aead_encrypt(plain, 1), { indent = true})
--local v = test_aead_encrypt(plain, 1)
--res = test_aead_encrypt(v, 0)
print(json.encode(res))
