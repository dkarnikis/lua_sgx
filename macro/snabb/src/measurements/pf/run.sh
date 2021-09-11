set -e
#rm -rf results
mkdir -p results
cd ../..
#echo "Starting Vanilla snabb"
#for i in program/wall/tests/data/*.pcap; do
#	prefix=vanilla
#    echo $(basename $i)
#    mkdir -p measurements/pf/results/$(basename $i) 
#    sudo ./snabb sgx_rules_remote $i measurements/pf/results/$(basename $i)/${prefix}_enc > measurements/pf/results/$(basename $i)/${prefix}_enc_res
#done

# local SGX
for i in program/wall/tests/data/*.pcap; do
	prefix=local_sgx
    echo $(basename $i)
    mkdir -p measurements/pf/results/$(basename $i) 
    sudo ./snabb sgx_rules_remote $i measurements/pf/results/$(basename $i)/${prefix}_enc > measurements/pf/results/$(basename $i)/${prefix}_enc_res
done

#
#
#echo "Starting Remote plain"
#for i in program/wall/tests/data/*.pcap; do
#	mkdir -p measurements/pf/results/$(basename $i) 
#	prefix=remote_sgx
#    echo $(basename $i)
#	sudo ./snabb sgx_rules_remote $i measurements/pf/results/$(basename $i)/${prefix}_enc 1 > measurements/pf/results/$(basename $i)/${prefix}_enc_res
#    sed -i 1d measurements/pf/results/$(basename $i)/${prefix}_enc_res
#	echo "Done"
#done
#
#
#echo "Starting Remote Opti"
#sleep 10
## remote plain opti
#for i in program/wall/tests/data/*.pcap; do
#	prefix=remote_sgx_opti
#    echo $(basename $i)
#    sudo ./snabb sgx_rules_remote $i measurements/pf/results/$(basename $i)/${prefix}_enc > measurements/pf/results/$(basename $i)/${prefix}_enc_res
#    sed -i 1d measurements/pf/results/$(basename $i)/${prefix}_enc_res
#done


#sleep 10
#echo "Starting Remote encrypted"
## remote encrypted
#for i in program/wall/tests/data/*.pcap; do
#	prefix=remote_sgx_enc
#    mkdir measurements/pf/results/$(basename $i) 
#    echo $(basename $i)
#    sudo ./snabb sgx_rules_remote $i measurements/pf/results/$(basename $i)/${prefix}_enc 1 > measurements/pf/results/$(basename $i)/${prefix}_enc_res
#    sed -i 1d measurements/pf/results/$(basename $i)/${prefix}_enc_res
#done
#
#
#
#
#echo "Starting Remote Opti Encrypted"
#sleep 10
## remote opti encrypted
#for i in program/wall/tests/data/*.pcap; do
#	prefix=remote_sgx_opti_encrypted
#    echo $(basename $i)
#    sudo ./snabb sgx_rules_remote $i measurements/pf/results/$(basename $i)/${prefix}_enc 1 > measurements/pf/results/$(basename $i)/${prefix}_enc_res
#    sed -i 1d measurements/pf/results/$(basename $i)/${prefix}_enc_res
#done
