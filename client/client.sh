#rm -f file_*
sleep 1
tmp=$2
last=16
loops=$1
for i in `seq 1 $tmp`;
do
	
	let data_size=$last
    for j in `seq 1 $loops`;
    do
 		cp /home/dkarnikis/sgxworks/lua_jit/measurements/metriseis/files/file_$data_size out
        ./client -s localhost -p 8888 -i test.lua -n 3 -m md5.lua -m bin.lua -m out
		sleep 1
    done
	last=($data_size*2)
done    
