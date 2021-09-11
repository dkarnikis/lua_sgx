echo "Remote SGX Opti DONE"
#sleep 10
pcaps=../../new_pcaps/
ls ${pcaps}
# remote opti encrypted
for i in ${pcaps}/*.pcap; do
    echo $(basename $i)
    sudo ./snabb luaguardia_firewall $i measurements/results/"$(basename $i)"_enc 1 > measurements/results/"$(basename $i)"_enc_res
    sed -i 1d measurements/results/$(basename $i)_enc_res
    sudo ./snabb luaguardia_firewall measurements/results/"$(basename $i)"_enc measurements/results/"$(basename $i)"_dec 0 > measurements/results/"$(basename $i)"_dec_res
    sed -i 1d measurements/results/"$(basename $i)"_dec_res
done