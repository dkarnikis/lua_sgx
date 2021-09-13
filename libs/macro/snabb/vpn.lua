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
    local plain = base64.decode(opt.data)
    local mode = opt.mode
    local res = ''
    if mode == "1" then
        res = test_aead_encrypt(plain, 1)
    else
        res = test_aead_encrypt(plain, 0)
    end
    -- encrypt the weird characters with base64
    return base64.encode(res)
end

return vpn
