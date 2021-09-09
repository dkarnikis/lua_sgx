mkdir -p results
echo "#bench Vanilla SGX_Local LuaGuardia" > results/wrk2_req.dat
echo "#bench Vanilla SGX_Local LuaGuardia" > results/wrk2_trans.dat

scripts=(luaguardia/counter.lua luaguardia/auth.lua luaguardia/report.lua)
for i in `seq 0 $((${#scripts[@]} -1))`;
do
    echo -n "$(basename ${scripts[$i]} .lua)" >> results/wrk2_req.dat
    echo -n "$(basename ${scripts[$i]} .lua)" >> results/wrk2_trans.dat
    for ((mode=0; mode<=2; mode++))
    do		
        echo "${scripts[$i]},$mode" > sconfig
        echo "${scripts[$i]},$mode"
        dat=$(./wrk -R 10000 -c1 -d 4 -t1 -s client.lua http://0.0.0.0:8080 | tail -n 2)
        reqs=$( echo -n $dat | head | awk '{print $2}')
        trans=$(echo -n $dat | tail | awk '{print $2}')
        echo -n " $reqs" >> results/wrk2_req.dat
        echo -n " $trans" >> results/wrk2_trans.dat
    done
    echo "" >> results/wrk2_req.dat
    echo "" >> results/wrk2_trans.dat
done
