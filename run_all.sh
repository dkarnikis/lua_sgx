LUA_TOP=$PWD
mkdir -p results
rm -rf results/
cd $LUA_TOP/lua_client/
lua bench.lua
cp -r $LUA_TOP/lua_client/results $LUA_TOP/results/micro
cd $LUA_TOP/macro/wrk2/
bash get.sh
cp -r results/* $LUA_TOP/results/
cd $LUA_TOP/macro/lsnabb/src
bash run_pf.sh
bash run_vpn.sh
cp -r results/* $LUA_TOP/results/

