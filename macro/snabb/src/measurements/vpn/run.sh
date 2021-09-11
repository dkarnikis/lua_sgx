set -e
#rm -rf results
#mkdir results
cd ../..
#local
for i in program/wall/tests/data/*.pcap; do
	echo $i
	prefix=vanilla
    echo $(basename $i)
    mkdir -p measurements/results/$(basename $i) 
    sudo ./snabb example_firewall_vanilla $i measurements/results/$(basename $i)/${prefix}_enc 1 > measurements/results/$(basename $i)/${prefix}_enc_res
    sed -i 1d measurements/results/$(basename $i)/${prefix}_enc_res
    sudo ./snabb example_firewall_vanilla measurements/results/$(basename $i)/${prefix}_enc measurements/results/$(basename $i)/${prefix}_dec 0 > measurements/results/$(basename $i)/${prefix}_dec_res
    sed -i 1d measurements/results/$(basename $i)/${prefix}_dec_res
done
#
#
#echo "Local SGX DONE"
#for i in program/wall/tests/data/*.pcap; do
#	echo $i
#	prefix=local_sgx
#    echo $(basename $i)
#    mkdir -p measurements/results/$(basename $i) 
#    sudo ./snabb example_firewall $i measurements/results/$(basename $i)/${prefix}_enc 1 > measurements/results/$(basename $i)/${prefix}_enc_res
#    sed -i 1d measurements/results/$(basename $i)/${prefix}_enc_res
#    sudo ./snabb example_firewall measurements/results/$(basename $i)/${prefix}_enc measurements/results/$(basename $i)/${prefix}_dec 0 > measurements/results/$(basename $i)/${prefix}_dec_res
#    sed -i 1d measurements/results/$(basename $i)/${prefix}_dec_res
#done

#remote plain
#for i in program/wall/tests/data/*.pcap; do
#	prefix=remote_sgx
#    echo $(basename $i)
#    sudo ./snabb firewall_remote $i measurements/results/$(basename $i)/${prefix}_enc 1 > measurements/results/$(basename $i)/${prefix}_enc_res
#    sed -i 1d measurements/results/$(basename $i)/${prefix}_enc_res
#    sudo ./snabb firewall_remote measurements/results/$(basename $i)/${prefix}_enc measurements/results/$(basename $i)/${prefix}_dec 0 > measurements/results/$(basename $i)/${prefix}_dec_res
#    sed -i 1d measurements/results/$(basename $i)/${prefix}_dec_res
#done

#
#
#echo "Remote SGX DONE"
#sleep 10
## remote encrypted
#for i in program/wall/tests/data/*.pcap; do
#	prefix=remote_sgx_enc
#    echo $(basename $i)
#    sudo ./snabb firewall_remote $i measurements/results/$(basename $i)/${prefix}_enc 1 e > measurements/results/$(basename $i)/${prefix}_enc_res
#    sed -i 1d measurements/results/$(basename $i)/${prefix}_enc_res
#    sudo ./snabb firewall_remote measurements/results/$(basename $i)/${prefix}_enc measurements/results/$(basename $i)/${prefix}_dec 0 e> measurements/results/$(basename $i)/${prefix}_dec_res
#    sed -i 1d measurements/results/$(basename $i)/${prefix}_dec_res
#done
#


#echo "Remote SGX Encrypted DONE"
## remote plain opti
#for i in program/wall/tests/data/*.pcap; do
#	prefix=remote_sgx_opti
#    echo $(basename $i)
#    sudo ./snabb firewall_remote $i measurements/results/$(basename $i)/${prefix}_enc 1 > measurements/results/$(basename $i)/${prefix}_enc_res
#    sed -i 1d measurements/results/$(basename $i)/${prefix}_enc_res
#    sudo ./snabb firewall_remote measurements/results/$(basename $i)/${prefix}_enc measurements/results/$(basename $i)/${prefix}_dec 0 > measurements/results/$(basename $i)/${prefix}_dec_res
#    sed -i 1d measurements/results/$(basename $i)/${prefix}_dec_res
#done
#

#echo "Remote SGX Opti DONE"
##sleep 10
## remote opti encrypted
#for i in program/wall/tests/data/*.pcap; do
#	prefix=remote_sgx_opti_encrypted
#    echo $(basename $i)
#    sudo ./snabb firewall_remote $i measurements/results/$(basename $i)/${prefix}_enc 1 e > measurements/results/$(basename $i)/${prefix}_enc_res
#    sed -i 1d measurements/results/$(basename $i)/${prefix}_enc_res
#    sudo ./snabb firewall_remote measurements/results/$(basename $i)/${prefix}_enc measurements/results/$(basename $i)/${prefix}_dec 0 e > measurements/results/$(basename $i)/${prefix}_dec_res
#    sed -i 1d measurements/results/$(basename $i)/${prefix}_dec_res
#done
#
#
