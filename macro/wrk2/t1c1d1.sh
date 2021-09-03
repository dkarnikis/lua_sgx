get_final_file() {
    echo "T${2}C${3}D${4}R${5} " > final_results_${1}_t${2}_c${3}_d${4}_r${5}
    cat vanilla/${1}_t${2}_c${3}_d${4}_t${5} >> final_results_${1}_t${2}_c${3}_d${4}_r${5}
    cat sgx_local/${1}_t${2}_c${3}_d${4}_t${5} >> final_results_${1}_t${2}_c${3}_d${4}_r${5}
    cat sgx_remote/${1}_t${2}_c${3}_d${4}_t${5} >> final_results_${1}_t${2}_c${3}_d${4}_r${5}
    cat sgx_remote_encrypted/${1}_t${2}_c${3}_d${4}_t${5} >> final_results_${1}_t${2}_c${3}_d${4}_r${5}
    cat sgx_remote_opti/${1}_t${2}_c${3}_d${4}_t${5} >> final_results_${1}_t${2}_c${3}_d${4}_r${5}
    cat sgx_remote_encrypted_opti/${1}_t${2}_c${3}_d${4}_t${5} >> final_results_${1}_t${2}_c${3}_d${4}_r${5}
    awk -v RS= -v OFS=" " '{$1 = $1} 1' final_results_${1}_t${2}_c${3}_d${4}_r${5} >o
    sed -i '1s/^/Bench Vanilla SGX_Local SGX_Rem SGX_Rem_Encr SGX_Rem_Opti SGX_Rem_Encr_Opti\n/' o
    mv o  final_results_${1}_t${2}_c${3}_d${4}_r${5}
}

get_final_file avg_requests 1 1 1 1000 
get_final_file avg_requests 1 1 5 1000 
get_final_file avg_requests 1 1 10 1000 
get_final_file avg_requests 1 2 1 1000 
get_final_file avg_requests 1 2 5 1000 
get_final_file avg_requests 1 2 10 1000 




get_final_file avg_transfers 1 1 1 1000 
get_final_file avg_transfers 1 1 5 1000 
get_final_file avg_transfers 1 1 10 1000 
get_final_file avg_transfers 1 2 1 1000 
get_final_file avg_transfers 1 2 5 1000 
get_final_file avg_transfers 1 2 10 1000 






