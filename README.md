# lua_sgx

## Deps
```
sudo apt-get install zlib1g zlib1g-dev liblua-dev5.3 libssl-dev git make unzip   
# Build and install ndpi [v1.8](https://github.com/ntop/nDPI/releases/tag/1.8)
# you may find 1.8 version in $LUA_ROOT/macro/
unzip nDPI-1.8.zip
cd nDPI-1.8/
./autogen.sh 
./configure
make
sudo make install
```
