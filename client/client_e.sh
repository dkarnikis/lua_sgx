#rm -f file_*
sleep 5
last=16
loops=$1
tmp=$2
for i in `seq 1 $tmp`;
do
	
	let data_size=$last
	cp /home/dkarnikis/sgxworks/lua_jit/measurements/metriseis/files/file_$data_size out
    for j in `seq 1 $loops`;
    do
        ./client -s localhost -p 8888 -i test.lua -n 3 -m md5.lua -m bin.lua -m out -e
		sleep 2
    done
	last=($data_size*2)
done    


