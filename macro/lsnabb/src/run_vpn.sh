mkdir -p results/vpn
rm -rf results/vpn/*
pcaps=../../new_pcaps/
cp ../../../configs/vpn_config ../../../lib_config
echo "#Bench Vanilla LocalSGX Luaguardia" > results/vpn.dat
for i in ${pcaps}/*.pcap; do
    for ((mode=0; mode<=2; mode++))
    do		
        echo $(basename $i .pcap) $mode
        sudo ./snabb luaguardia_firewall $i out 1 $mode> results/vpn/"$(basename $i .pcap)"_enc_res_$mode
        sudo ./snabb luaguardia_firewall out base 0 $mode > results/vpn/"$(basename $i .pcap)"_dec_res_$mode
        rm -f out base
    done
    cd results/vpn
    paste "$(basename $i .pcap)"_enc_res_0 "$(basename $i .pcap)"_dec_res_0 | awk '{print $1 + $3; }' > "$(basename $i .pcap)_0"
    paste "$(basename $i .pcap)"_enc_res_1 "$(basename $i .pcap)"_dec_res_1 | awk '{print $1 + $3; }' > "$(basename $i .pcap)_1"
    paste "$(basename $i .pcap)"_enc_res_2 "$(basename $i .pcap)"_dec_res_2 | awk '{print $1 + $3; }' > "$(basename $i .pcap)_2"
    echo "$(basename $i .pcap) $(cat $(basename $i .pcap)_0) $(cat $(basename $i .pcap)_2) $(cat $(basename $i .pcap)_1)" >> ../vpn.dat
    cd -
done
