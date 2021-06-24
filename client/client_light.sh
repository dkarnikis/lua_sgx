#rm -f file_*
if [ -z "$5" ]
  then
    echo "Give the code File"                             
    read -r b                                             
    echo "Number of modules"                              
    read -r n                                             
     
                                                    
cmd="./client -s 139.91.90.168 -p 8888 -i $b -n $n " 
echo $cmd                                             
for i in `seq 1 $n`;                                  
do                                                    
    echo "Give module name"                           
    read -r b                                         
    cmd+=" -m "                                       
    cmd+=$b                                           
done                                                  
    else
    echo "$1 $2 $3 $4 $5"
    cmd="./client -s 139.91.90.168 -p 8888 -i $1 -n $2 -m $3 -m $4 -m $5 "
fi

tmp=22
last=16
loops=5
for i in `seq 1 $tmp`;
do
	let data_size=$last
	echo "Sending $data_size bytes"

    ./a.out $data_size out
    for j in `seq 1 $loops`;
    do
        echo "Loop = $j"
		$cmd #> /dev/null
	    echo "Done loop $j"	
		sleep 0.1
    done
	last=($data_size*2)
done    

sleep 1

tmp=22
last=16
loops=5
echo "Running encryption remote "
cmd+=" -e "  
for i in `seq 1 $tmp`;
do
	
	let data_size=$last
	echo "Sending $data_size bytes"
    ./a.out $data_size out
    for j in `seq 1 $loops`;
    do

        echo "Loop = $j"
		$cmd #> /dev/null
	    echo "Done loop $j"	
		sleep 0.1
    done
	last=($data_size*2)
done    

sleep 1
echo "Running encrypted Optimizations"
tmp=22
last=16
loops=5

for i in `seq 1 $tmp`;
do
	
	let data_size=$last
	echo "Sending $data_size bytes"
    ./a.out $data_size out
    for j in `seq 1 $loops`;
    do

        echo "Loop = $j"
		$cmd #> /dev/null
	    echo "Done loop $j"	
		sleep 0.5
    done
	last=($data_size*2)
done    


