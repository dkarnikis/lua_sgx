folder=(counter auth report)
#rm -rf results
scripts=(scripts/counterl scripts/authl scripts/reportl)
exec_func() {
	# $1 = script_name
	# $2 = thread count
	# $3 = connection num
	# $4 = duration time
	# $5 = throughput rate
	# $6 = t_avg
	# $7 = r_avg
	# $8 = t_type
	# $9 = type_folder
	local -n t_avg_l=$6
	local -n r_avg_l=$7
	local -n t_type_l=$8
	
	TRANSFERS="$(cat /tmp/h | grep -E "^1:|Transfer")"
	REQUESTS="$(cat /tmp/h | grep -E "^1:|Request")"
	echo  ${TRANSFERS} >> results/$1/$9/transfers_t${thread_size}_c${connection_size}_d${duration_size}_t${throughput_size}
	echo  ${REQUESTS} >> results/$1/$9/requests_t${thread_size}_c${connection_size}_d${duration_size}_t${throughput_size}
	#t_type_l=$(printf '%s' "$TRANSFERS" | sed 's/[0-9.0-9]*//g' | awk '{print $NF}')
	t_num=$(echo ${TRANSFERS} | grep -Eo '[+]?[0-9]+([.][0-9]+)?')
	r_num=$(echo ${REQUESTS} | grep -Eo '[+]?[0-9]+([.][0-9]+)?')
	t_avg_l=$(echo "scale=4; ${t_avg_l} + ${t_num}" | bc -l)
	r_avg_l=$(echo "scale=4; ${r_avg} + ${r_num}" | bc -l)
}

local_execution() {
	mkdir -p results
	let thread_size=$1
	let connection_size=$2
	let duration_size=$3
	let throughput_size=1000
	let iterations=3
	cmd="./wrk -c${connection_size} -d${duration_size} -t${thread_size} -R${throughput_size} http://139.91.70.29:80"
	for i in `seq 0 $((${#scripts[@]} -1))`;
	do
		echo "Running ${scripts[$i]}"
		mkdir -p results/${folder[$i]}/vanilla
		let t_avg=0
		let r_avg=0
		let t_type="x" 
		for ((k=1; k<=${iterations}; k++))
		do		
			OUTPUT=$(${cmd} -s ${scripts[$i]}.lua > /tmp/h)
			exec_func ${folder[$i]} ${thread_size} ${connection_size} ${duration_size} ${throughput_size} t_avg r_avg t_type vanilla
			##./${cmd} | grep -E "^#1:|Requests|^#1:|Transfer" >> results
		done
		t_avg=$(echo "scale=5; ${t_avg} / ${iterations}" | bc -l)
		r_avg=$(echo "scale=5; ${r_avg} / ${iterations}" | bc -l)
		echo "${t_avg} " > results/${folder[$i]}/vanilla/avg_transfers_t${thread_size}_c${connection_size}_d${duration_size}_t${throughput_size}
		echo ${r_avg} > results/${folder[$i]}/vanilla/avg_requests_t${thread_size}_c${connection_size}_d${duration_size}_t${throughput_size}
	done
}

sgx_local_execution() {
	scripts=(scripts/auth_scripts/auth scripts/counter_scripts/counter) #scripts/report_scripts/report)
	dir="sgx_local"
	mkdir -p results
	let thread_size=$1
	let connection_size=$2
	let duration_size=$3
	let throughput_size=1000
	let iterations=3
	cmd="./wrk -c${connection_size} -d${duration_size} -t${thread_size} -R${throughput_size} http://139.91.70.29:80"
	for i in `seq 0 $((${#scripts[@]} -1))`;
	do
		echo "Running ${scripts[$i]}"
		mkdir -p results/${folder[$i]}/${dir}
		let t_avg=0
		let r_avg=0
		let t_type="x" 
		for ((k=1; k<=${iterations}; k++))
		do
			
			OUTPUT=$(${cmd} -s ${scripts[$i]}.lua > /tmp/h)
			exec_func ${folder[$i]} ${thread_size} ${connection_size} ${duration_size} ${throughput_size} t_avg r_avg t_type sgx_local
			##./${cmd} | grep -E "^#1:|Requests|^#1:|Transfer" >> results
		done
		t_avg=$(echo "scale=5; ${t_avg} / ${iterations}" | bc -l)
		r_avg=$(echo "scale=5; ${r_avg} / ${iterations}" | bc -l)
		echo "${t_avg} " > results/${folder[$i]}/${dir}/avg_transfers_t${thread_size}_c${connection_size}_d${duration_size}_t${throughput_size}
		echo ${r_avg} > results/${folder[$i]}/${dir}/avg_requests_t${thread_size}_c${connection_size}_d${duration_size}_t${throughput_size}
	done
}





sgx_remote_execution() {
	scripts=(scripts/counter_scripts/counter scripts/auth_scripts/auth scripts/report_scripts/report)
	dir="sgx_remote"
	mkdir -p results
	let thread_size=$1
	let connection_size=$2
	let duration_size=$3
	let throughput_size=1000
	let iterations=3
	rm -rf results/${dir}
	cmd="./wrk -c${connection_size} -d${duration_size} -t${thread_size} -R${throughput_size} http://139.91.70.29:80"
	for i in `seq 0 $((${#scripts[@]} -1))`;
	do
		echo "Running ${scripts[$i]}"
		mkdir -p results/${folder[$i]}/${dir}
		let t_avg=0
		let r_avg=0
		let t_type="x" 
		for ((k=1; k<=${iterations}; k++))
		do
			
			OUTPUT=$(${cmd} -s ${scripts[$i]}_remote.lua > /tmp/h)
			exec_func ${folder[$i]} ${thread_size} ${connection_size} ${duration_size} ${throughput_size} t_avg r_avg t_type ${dir}
			##./${cmd} | grep -E "^#1:|Requests|^#1:|Transfer" >> results
		done
		t_avg=$(echo "scale=5; ${t_avg} / ${iterations}" | bc -l)
		r_avg=$(echo "scale=5; ${r_avg} / ${iterations}" | bc -l)
		echo "${t_avg} " > results/${folder[$i]}/${dir}/avg_transfers_t${thread_size}_c${connection_size}_d${duration_size}_t${throughput_size}
		echo ${r_avg} > results/${folder[$i]}/${dir}/avg_requests_t${thread_size}_c${connection_size}_d${duration_size}_t${throughput_size}
		echo "Done ${scripts[$i]}"
	done
}


sgx_remote_execution_opti() {
	scripts=(scripts/counter_scripts/counter scripts/auth_scripts/auth scripts/report_scripts/report)
	dir="sgx_remote_opti"
	rm -rf results/${dir}
	mkdir -p results
	let thread_size=$1
	let connection_size=$2
	let duration_size=$3
	let throughput_size=1000
	let iterations=3
	cmd="./wrk -c${connection_size} -d${duration_size} -t${thread_size} -R${throughput_size} http://139.91.70.29:80"
	for i in `seq 0 $((${#scripts[@]} -1))`;
	do
		echo "Running ${scripts[$i]}"
		mkdir -p results/${folder[$i]}/${dir}
		let t_avg=0
		let r_avg=0
		let t_type="x" 
		for ((k=1; k<=${iterations}; k++))
		do
			
			OUTPUT=$(${cmd} -s ${scripts[$i]}_remote.lua > /tmp/h)
			exec_func ${folder[$i]} ${thread_size} ${connection_size} ${duration_size} ${throughput_size} t_avg r_avg t_type ${dir}
			##./${cmd} | grep -E "^#1:|Requests|^#1:|Transfer" >> results
		done
		t_avg=$(echo "scale=5; ${t_avg} / ${iterations}" | bc -l)
		r_avg=$(echo "scale=5; ${r_avg} / ${iterations}" | bc -l)
		echo "${t_avg} " > results/${folder[$i]}/${dir}/avg_transfers_t${thread_size}_c${connection_size}_d${duration_size}_t${throughput_size}
		echo ${r_avg} > results/${folder[$i]}/${dir}/avg_requests_t${thread_size}_c${connection_size}_d${duration_size}_t${throughput_size}
		echo "Done ${scripts[$i]}"
	done
}


sgx_remote_execution_encrypted_opti() {
	scripts=(scripts/counter_scripts/counter scripts/auth_scripts/auth scripts/report_scripts/report)
	dir="sgx_remote_encrypted_opti"
	mkdir -p results
	let thread_size=$1
	let connection_size=$2
	let duration_size=$3
	let throughput_size=1000
	let iterations=3
	cmd="./wrk -c${connection_size} -d${duration_size} -t${thread_size} -R${throughput_size} http://139.91.70.29:80"
	for i in `seq 0 $((${#scripts[@]} -1))`;
	do
		echo "Running ${scripts[$i]}"
		mkdir -p results/${folder[$i]}/${dir}
		let t_avg=0
		let r_avg=0
		let t_type="x" 
		for ((k=1; k<=${iterations}; k++))
		do
			OUTPUT=$(${cmd} -s ${scripts[$i]}_remote_e.lua > /tmp/h)
			exec_func ${folder[$i]} ${thread_size} ${connection_size} ${duration_size} ${throughput_size} t_avg r_avg t_type ${dir}
			##./${cmd} | grep -E "^#1:|Requests|^#1:|Transfer" >> results
		done
		t_avg=$(echo "scale=5; ${t_avg} / ${iterations}" | bc -l)
		r_avg=$(echo "scale=5; ${r_avg} / ${iterations}" | bc -l)
		echo "${t_avg} " > results/${folder[$i]}/${dir}/avg_transfers_t${thread_size}_c${connection_size}_d${duration_size}_t${throughput_size}
		echo ${r_avg} > results/${folder[$i]}/${dir}/avg_requests_t${thread_size}_c${connection_size}_d${duration_size}_t${throughput_size}
		echo "Done ${scripts[$i]}"
	done
}


sgx_remote_execution_encrypted() {
	scripts=(scripts/counter_scripts/counter scripts/auth_scripts/auth scripts/report_scripts/report)
	dir="sgx_remote_encrypted"
	mkdir -p results
	let thread_size=$1
	let connection_size=$2
	let duration_size=$3
	let throughput_size=1000
	let iterations=3
	cmd="./wrk -c${connection_size} -d${duration_size} -t${thread_size} -R${throughput_size} http://139.91.70.29:80"
	echo $cmd
	for i in `seq 0 $((${#scripts[@]} -1))`;
	do
		echo "Running ${scripts[$i]}"
		mkdir -p results/${folder[$i]}/${dir}
		let t_avg=0
		let r_avg=0
		let t_type="x" 
		for ((k=1; k<=${iterations}; k++))
		do
			OUTPUT=$(${cmd} -s ${scripts[$i]}_remote_e.lua > /tmp/h)
			exec_func ${folder[$i]} ${thread_size} ${connection_size} ${duration_size} ${throughput_size} t_avg r_avg t_type ${dir}
	
			##./${cmd} | grep -E "^#1:|Requests|^#1:|Transfer" >> results
		done
		t_avg=$(echo "scale=5; ${t_avg} / ${iterations}" | bc -l)
		r_avg=$(echo "scale=5; ${r_avg} / ${iterations}" | bc -l)
		echo "${t_avg} " > results/${folder[$i]}/${dir}/avg_transfers_t${thread_size}_c${connection_size}_d${duration_size}_t${throughput_size}
		echo ${r_avg} > results/${folder[$i]}/${dir}/avg_requests_t${thread_size}_c${connection_size}_d${duration_size}_t${throughput_size}
		echo "Done ${scripts[$i]}"
	done
}













#
#
#
#
#local_execution 1 1 1
#local_execution 1 1 5
local_execution 1 1 10
#local_execution 1 1 20
#
#local_execution 1 2 1
#local_execution 1 2 5
#local_execution 1 2 10
#sgx_local_execution 1 1 1
#sgx_local_execution 1 1 5
#sgx_local_execution 1 1 10

#sgx_local_execution 1 2 1
#sgx_local_execution 1 2 5
#sgx_local_execution 1 2 10
##
#sleep 1
#echo "Start the remove server with encryption"
#
#
#sgx_remote_execution_encrypted 1 1 1
#sgx_remote_execution_encrypted 1 1 5
#sgx_remote_execution_encrypted 1 1 10
#
#sgx_remote_execution_encrypted 1 2 1
#sgx_remote_execution_encrypted 1 2 5
#sgx_remote_execution_encrypted 1 2 10
#
#echo "Start the remove server with optimizations with encryption"
#echo "Start the remove server with optimizations with encryption"
#echo "Start the remove server with optimizations with encryption"
#echo "Start the remove server with optimizations with encryption"
#sleep 20
#sgx_remote_execution_encrypted_opti 1 1 1
#sgx_remote_execution_encrypted_opti 1 1 5
sgx_remote_execution_encrypted_opti 1 1 10
#
#sgx_remote_execution_encrypted_opti 1 2 1
#sgx_remote_execution_encrypted_opti 1 2 5
#sgx_remote_execution_encrypted_opti 1 1 10
##
