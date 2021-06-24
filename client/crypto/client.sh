cp ../client .                                               
gcc rand.c
bench_id=(md5 sha256 sha512)
bench_deps=(md5.lua sha2.lua sha2.lua)

cmd="./client -s 139.91.90.168 -p 8888 -i bench.lua -n 3 -m bin.lua -m out -m "

loops=5
tmp=33554432 
last=16

remote_plain() { 
    for i in `seq 0 $((${#bench_id[@]} -1))`;
    do
        cmd="./client -s 139.91.90.168 -p 8888 -i bench.lua -n 3 -m bin.lua -m out -m "
        cmd+=" ${bench_deps[$i]}" 
        # modifier for benchmark runs, heavy benchmarks need less runs           
        data_size=0
        last=16
        while [[ "$data_size" != "$tmp" ]]
        do
            echo "Sending ${bench_id[$i]}"
            let data_size=$last
            cp ${bench_id[$i]}/*.lua .
            ./a.out $data_size out
            for j in `seq 1 $loops`;
            do
                echo "Loop = $j"
                $cmd
                echo $cmd
                echo "Done loop $j"	
                sleep 0.1
            done
            last=($last*2)
        done
    done    
}

remote_encrypted() {
    echo "Running encryption remote "
    for i in `seq 0 $((${#bench_id[@]} -1))`;
    do
        cmd="./client -s 139.91.90.168 -p 8888 -i bench.lua -e -n 3 -m bin.lua -m out -m "
        cmd+=" ${bench_deps[$i]}" 

        # modifier for benchmark runs, heavy benchmarks need less runs           
        data_size=0
        last=16
        while [[ "$data_size" != "$tmp" ]]
        do
            echo "Sending ${bench_id[$i]}"
            let data_size=$last
            cp ${bench_id[$i]}/*.lua .
            ./a.out $data_size out
            for j in `seq 1 $loops`;
            do
                echo "Loop = $j"
                $cmd
                echo $cmd
                echo "Done loop $j"	
                sleep 0.1
            done
            last=($last*2)
        done
    done    
}

remote_encrypted_opti() {
    loops=6
    echo "Running encrypted Optimizations"
    for i in `seq 0 $((${#bench_id[@]} -1))`;
    do
        cmd="./client -s 139.91.90.168 -p 8888 -i bench.lua -e -n 3 -m bin.lua -m out -m "
        cmd+=" ${bench_deps[$i]}" 
        # modifier for benchmark runs, heavy benchmarks need less runs           
        data_size=$last
        last=16
        while [[ "$data_size" != "$tmp" ]]
        do
            echo "Sending ${bench_id[$i]}"
            let data_size=$last
            cp ${bench_id[$i]}/*.lua .
            ./a.out $data_size out
            for j in `seq 1 $loops`;
            do
                echo "Loop = $j"
                echo $cmd
                $cmd
                echo "Done loop $j"	
                sleep 0.1
            done
            last=($last*2)
        done
    done
}


remote_plain 
remote_encrypted
remote_encrypted_opti
