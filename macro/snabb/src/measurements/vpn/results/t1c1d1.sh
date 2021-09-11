test -e
get_final_file() {
    echo "T${2}C${3}D${4}R${5} " > final_results_${1}_t${2}_c${3}_d${4}_r${5}
    cat vanilla/${1}_t${2}_c${3}_d${4}_t${5} >> final_results_${1}_t${2}_c${3}_d${4}_r${5}
    cat sgx_local/${1}_t${2}_c${3}_d${4}_t${5} >> final_results_${1}_t${2}_c${3}_d${4}_r${5}
    cat sgx_remote_encrypted/${1}_t${2}_c${3}_d${4}_t${5} >> final_results_${1}_t${2}_c${3}_d${4}_r${5}
    cat sgx_remote_encrypted_opti/${1}_t${2}_c${3}_d${4}_t${5} >> final_results_${1}_t${2}_c${3}_d${4}_r${5}
    awk -v RS= -v OFS=" " '{$1 = $1} 1' final_results_${1}_t${2}_c${3}_d${4}_r${5} >o
    sed -i '1s/^/Bench Vanilla SGX_Local SGX_Rem_Encr SGX_Rem_Encr_Opti\n/' o
    mv o  final_results_${1}_t${2}_c${3}_d${4}_r${5}
}


for d in */ ; do
    vanilla=vanilla_enc_res
    local=local_sgx_enc_res
    rem_enc=remote_sgx_encrypted_enc_res
    rem_enc_opt=remote_sgx_encrypted_opti_enc_res
    cd $d
        f=$(awk '{ print $4  }' ${local})
        
        a=$(echo "$d" | tr --delete "\.pcap/")
        echo "$a-$f" > t
        awk '{ print $2  }' ${vanilla} > v
        awk '{ print $2  }' ${local} > f1
        awk '{ print $2  }' ${rem_enc} > f4
        awk '{ print $2  }' ${rem_enc_opt} > f5
        paste  t v f1 f4 f5 | column  -s',' > final_enc
        sed -i '1s/^/Bench Vanilla SGX_Local SGX_Rem_Enc SGX_Rem_Encr_Opti\n/' final_enc
    echo "$d"
    cd -
done

for d in */ ; do
    vanilla=vanilla_dec_res
    local=local_sgx_dec_res
    rem_dec=remote_sgx_encrypted_dec_res
    rem_dec_opt=remote_sgx_encrypted_opti_dec_res
    cd $d
        f=$(awk '{ print $4  }' ${local})
        
        a=$(echo "$d" | tr --delete "\.pcap/")
        echo "$a-$f" > t

        awk '{ print  $2 }' ${vanilla} > v
        awk '{ print  $2 }' ${local} > f1
        awk '{ print  $2 }' ${rem_dec} > f4
        awk '{ print  $2 }' ${rem_dec_opt} > f5
        paste t v f1 f4 f5 | column  -s',' > final_dec
        sed -i '1s/^/Bench Vanilla SGX_Local SGX_Rem_Enc SGX_Rem_Encr_Opti\n/' final_dec
    echo "$d"
    cd -
done


