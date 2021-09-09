echo "Exporting Variables"
export LUA_TOP=$PWD
export LUAG_CLIENT=$LUA_TOP/lua_client/native_client
echo "Building vanilla lua VM"
# build remote lua vm without SGX
cd $LUA_TOP/App/lua_lib
make linux
cp libdlua.so $LUA_TOP
echo "Building LuaGuardia client for lua5.3"
# build native lua client for lua5.3
cd $LUAG_CLIENT
make clean;make
cp liblclient.so $LUA_TOP/lua_client/
echo "Building wrk2"
cd $LUA_TOP/macro/wrk2
make clean;make
echo "Building LuaGuardia client for wrk2 using luajit"
# build native wrk lua client with jit
cd $LUAG_CLIENT
make clean; make wrk=1
cp liblclient.so $LUA_TOP/macro/wrk2
echo "Building LuaGuardia"
cd $LUA_TOP/
make clean;make
echo "Don't forget to \`export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$LUA_TOP\`"
export LD_LIBRARY_TOP=$PWD:$LD_LIBRARY_TOP
echo "Building darkhttp for wrk2"
cd $LUA_TOP/macro/darkhttpd
make clean;make
