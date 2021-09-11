test -e

for d in */ ; do
    vanilla=vanilla_enc_res
    local=local_sgx_enc_res
    rem=remote_sgx_enc_res
    rem_opt=remote_sgx_opti_enc_res
    rem_enc=remote_sgx_enc_enc_res
    rem_enc_opt=remote_sgx_opti_encrypted_enc_res
    cd $d
        f=$(awk '{ print $4  }' ${local})
        a=$(echo "$d" | tr --delete "\.pcap/")
        echo "$a-$f" > t
        cat ${vanilla} | tail -n 1 > 1
        mv 1 ${vanilla}
        cat ${local} | tail -n 1 > 1
        mv 1 ${local}
        cat ${rem} | tail -n 1 > 1
        mv 1 ${rem}
        cat ${rem_opt} | tail -n 1 > 1
        mv 1 ${rem_opt}
        cat ${rem_enc} | tail -n 1 > 1
        mv 1 ${rem_enc}
        cat ${rem_enc_opt} | tail -n 1 > 1
        mv 1 ${rem_enc_opt}
        awk '{ print $2  }' ${vanilla} > v
        awk '{ print $2  }' ${local} > f1
        awk '{ print $2  }' ${rem} > f2
        awk '{ print $2  }' ${rem_opt} > f3
        awk '{ print $2  }' ${rem_enc} > f4
        awk '{ print $2  }' ${rem_enc_opt} > f5
        paste -d, t v f1 f2 f3 f4 f5 | column  -s',' -n -t > final_enc
        sed -i '1s/^/Bench Vanilla SGX_Local SGX_Rem SGX_Rem_Opti SGX_Rem_Enc SGX_Rem_Encr_Opti\n/' final_enc
    echo "$d"
    cd -
done



