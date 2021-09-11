export LUA_TOP=$PWD
cd $LUA_TOP
make clean
find . -name "*.so" | xargs -n1 rm -f
cd App/lua_lib
make clean
cd $LUA_TOP/macro/darkhttpd
make clean
cd $LUA_TOP/macro/wrk2/
make clean
cd $LUA_TOP/lua_client/native_client
make clean
rm -rf $LUA_TOP/lua_client/results
rm -rf $LUA_TOP/macro/wrk2/results
cd $LUA_TOP/macro/snabb-2019.11/
make clean
cd $LUA_TOP
find . -name "tags" | xargs rm -f
find . -name "out" | xargs rm -f
find . -name "output" | xargs rm -f
rm -f code.lua
