a=require('foo')
server="127.0.0.1"
port=8000
socket=a.lconnect(server, port)
aes_key = a.lhandshake(socket)
a.lsend_file(socket, "l.lua", aes_key);
res = a.lrecv_response(socket, aes_key);
print("Result", res)
