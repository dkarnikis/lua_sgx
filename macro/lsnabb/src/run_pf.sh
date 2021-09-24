mkdir -p results/pf
rm -rf results/pf/*
pcaps=../../new_pcaps
#cp ../../../configs/pflua_config ../../../lib_config
echo "#Bench Vanilla Luaguardia Local_SGX" > results/pf.dat
for i in ${pcaps}/*.pcap; do
    for ((mode=0; mode<=2; mode++))
    do		
        echo $(basename $i .pcap) $i
        sudo ./snabb sgx_rules_remote $i out $mode |tail -n1 > results/pf/"$(basename $i .pcap)"_$mode
        rm -f out
    done
    cd results/pf
    paste "$(basename $i .pcap)"_0 "$(basename $i .pcap)"_2 "$(basename $i .pcap)"_1 | awk '{print $1 " " $2 " " $3; }' > data.out
    echo "$(basename $i .pcap) $(cat data.out)" >> ../pf.dat
    cd -
done
