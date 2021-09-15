LUA_TOP=$PWD
mkdir -p results
rm -rf results/
cd $LUA_TOP/lua_client/
lua bench.lua
cp -r $LUA_TOP/lua_client/results results/micro
