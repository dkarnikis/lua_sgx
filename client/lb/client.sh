 cp ../client .
 #bench_id=(light/array3d light/bounce light/chamenos light/deltablue light/fannkuch_redux light/life light/mandelbrot light/partialsums light/queens light/ray light/fasta  light/richards  light/series   heavy/binarytrees heavy/nbody  heavy/recursive_fib heavy/collisiondetector heavy/havlak) #)heavy/spectralnorm)


 cmd="./client -s 139.91.90.18 -p 8888 -i bench.lua -n 1 -m som.lua"
 bench_id=(light/life)
 loops=3
 tmp=50
 step=10
 remote_plain() {
     loops=$1
     for i in `seq 0 $((${#bench_id[@]} -1))`;
     do
         # modifier for benchmark runs, heavy benchmarks need less runs
         if [[ ${bench_id[$i]} == *"heavy"* ]]; then
             tmp=40
         else
             tmp=100
         fi
         data_size=0
         while [[ "$data_size" != "$tmp" ]]
         do
             echo "Sending ${bench_id[$i]}"
             let data_size=$((data_size + $step))
             cp ${bench_id[$i]}/*.lua .
             #echo "$data_size" > out
             sed '$d' bench.lua > l
             mv l bench.lua
             echo  "run_iter($data_size)" >> bench.lua

             for j in `seq 1 $loops`;
             do
                 #echo "Loop = $j"
                 $cmd
                 echo $cmd
                 #echo "Done loop $j"
                 sleep 0.1
             done
         done
     done
     #sleep 5
 }

 #plain remote
 #remote_plain 3
 # plain opti
 #remote_plain 4
 cmd+=" -e "
 # encrypted  remote
 #remote_plain 3
 # optimization  encrypted
 remote_plain 4

