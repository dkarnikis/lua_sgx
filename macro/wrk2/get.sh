mkdir -p results
rm -rf results/*
echo "#bench Vanilla LuaGuardia SGX_Local" > results/wrk2_req.dat
echo "#bench Vanilla LuaGuardia SGX_Local" > results/wrk2_trans.dat

scripts=(luaguardia/counter.lua luaguardia/auth.lua luaguardia/report.lua)
for i in `seq 0 $((${#scripts[@]} -1))`;
do
    echo -n "$(basename ${scripts[$i]} .lua)" >> results/wrk2_req.dat
    echo -n "$(basename ${scripts[$i]} .lua)" >> results/wrk2_trans.dat
    for ((mode=0; mode<=2; mode++))
    do		
        echo "${scripts[$i]},$mode" > sconfig
        echo "${scripts[$i]},$mode"
        dat=$(./wrk -R 1000 -c1 -d 60 -t1 -s client.lua http://128.30.64.222:8080 | tail -n 2)
        printf "%s\n" "${scripts[$i]},$mode" >>  "results/$(basename ${scripts[$i]} .lua)"
        printf "%s\n" "$dat" >> "results/$(basename ${scripts[$i]} .lua)"
        reqs=$(echo -n "$dat" | head -n1 | awk '{print $2}')
        trans=$(echo -n "$dat" | tail -n1 | awk '{print $2}')
        printf " %s" "$reqs" >> results/wrk2_req.dat
        printf " %s" "$trans" >> results/wrk2_trans.dat
    done
    echo "" >> results/wrk2_req.dat
    echo "" >> results/wrk2_trans.dat
done
