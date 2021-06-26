#include <time.h>
#include <unistd.h>
#include <stdlib.h>  
#include <vector>
#include <thread>       
#include <stdint.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <sys/types.h>
#include <netdb.h>
#include <sys/socket.h>
#include <sys/param.h>
#include <sys/stat.h>
#include "sgx_urts.h"
#include "sgx_defs.h"
#include "Enclave_u.h"
#include "commands.h"
#include "../Enclave/dh/tools.h"
#include "../Enclave/dh/tweetnacl.h"
#include "funcs.h"
#include "nw.h"
#define LOCATION __LINE__,__FILE__,__func__
/*
 * The enclave where enclave.signed.so is stored
 */
char *enclave_path = NULL;
 /* 
  * Don't print on screen the lua results
  */
int disable_execution_output;
/* 
 * flag for fast enclave mode
 */
short enclave_instatiated;	
pthread_mutex_t clients_lock;
/*
 * The enclave id
 */
sgx_enclave_id_t unique_eid;
/*
 * The socket that the main client connects to
 */
int new_socket;
/*
 * timers for benchmarks
 */
double sgx_time = 0.0f, e2e_time = 0.0f, exec_time = 0.0f;
struct timespec te2e_start = {0, 0}, te2e_stop = {0, 0}, tsgx_start{0, 0}, tsgx_stop{0, 0}, 
                texec_start{0, 0}, texec_stop{0, 0};
/*
 * Don't print the execution statistics eg timers
 */
int disable_timer_print = 0;
/* 
* skip the first results in single enclave
* instance, we skip the sgx init results
* and keep only the optimizations
*/
int which_run_am_i;
/*
 * Optimized mode for lua. Uses the same enclave for all executions
 */
int single_enclave_instance = 0; 

void
execute_code_thread(long unsigned int eid, int n_socket)
{
    sgx_status_t ret;
    (void)(ret);
    ret = ecall_execute(eid, n_socket);
#ifdef DEBUG
    val_error(ret, SGX_SUCCESS, LOCATION, "Failed to execute lua code", 0);
    fprintf(stdout, "-> Code executed, results sent to the client\n");
    fprintf(stdout, "-> Connections with the client terminated\n");
#endif
}

int
main (int argc, char **argv)
{
    clock_gettime(CLOCK_REALTIME, &te2e_start);
    sgx_status_t ret;
    struct thread_data *td;         /* init values for the service daemon   */
    short local_execution;          /* are we running on local  ?       */
    short unsigned int daemon_port; /* port that the daemon will listen to  */
    int i;                          /* counter for pushing args in lua VM   */
    int opt;                        /* var for parsing args                 */
    char *input_file;               /* the file to open for execution       */
    /* init */
	(void)(ret);
    disable_execution_output = 0;
    single_enclave_instance = 0;
    input_file = NULL;
    daemon_port = 0;
    local_execution = 0;
    /* init the exec time values */
    sgx_time = 0.0f;
    /*
     * Get arguments
     */
    while ((opt = getopt(argc, argv, "p:e:l:i:ftdh")) != -1) { 
        switch (opt) {
			case 'e':
				enclave_path = strdup(optarg);
				break;
            case 'd':
                disable_execution_output = 1;
                break;
            case 't':
                disable_timer_print = 1;
                break;
            case 'p':
                daemon_port = (short unsigned int)atoi(optarg);
                break;
            case 'l':
                local_execution = 1;
                input_file = strdup(optarg);
                break;
            case 'f':
                single_enclave_instance = 1;
                break;
            case 'h':
            default:
                usage();
        }
    }
    check_args(daemon_port, local_execution, input_file);
    /* 
	 * lua accepts arguments as follows ./app FILE extra parameters         
     * in our case we do ./app -p port -i file extra params                 
     * so we must give to lua all the arguments -i file extra params      
     */
	if (enclave_path == NULL)
		enclave_path = strdup("enclave.signed.so");
#ifdef DEBUG
	/* check if enclave file do not exist */
	i = access(enclave_path, F_OK);
	if (i == -1) {
		perror("Invalid enclave path");
		abort();
	}
#endif
	int welcome_socket;
	/* spawn our socket */
	welcome_socket = l_create_socket(daemon_port);
    /* accept the new connection */
    new_socket = l_accept(welcome_socket);
    /* reset e2e time */
    e2e_time = 0.0f;
    clock_gettime(CLOCK_REALTIME, &te2e_start);
    unique_eid = l_setup_enclave();
    spawn_lua_enclave(new_socket);
	free(enclave_path);
	free(input_file);
}

/*
 * Receive all the modules from the client. Decryption will happen inside the enclave,
 * all the data are stored in the untrusted filesystem encryped or not. On success,
 * 0 is returned, else -1 and the connection with the client closes 
 */
int
receive_modules(int n_socket)
{
    int i, k;                           /* counters                         */
    int module_name_len;                /* module name len                  */
    char *module_data;                  /* will hold the data of the module */
    char buffer[2048];
    char *module_name;                  /* will hold the name of the module */
    char *p;
    FILE *module;
    int number_of_modules;
    int module_len;
    i = k = module_name_len = number_of_modules = module_len = 0;
    p = NULL;
    /* receive modules of the user */
    recv_number(n_socket, &number_of_modules);
    for (i = 0; i < number_of_modules; i++){
        module_name = module_data = NULL;
        /* got the module size */
        recv_number(n_socket, &module_len);
#ifdef DEBUG1
        fprintf(stdout, "module size = %d\n", module_len);
#endif
        /* allocate the buffer to hold the module   */
        module_data = (char *)calloc(1, module_len * sizeof(char));
#ifdef DEBUG
        check_error(module_data, LOCATION, "Failed to allocate module data");
#endif
        /* receive the module                       */
        if (recv_data(n_socket, module_data, module_len) == -1)
            return -1;
        memset(buffer, 0, 2048);
        if (recv_data(n_socket, buffer, 2048) == -1)
            return -1;
        /* fuck tcp dude */
        p = strtok(buffer, "@");
        p = strtok(buffer, "@");
        /* create the file and write the encrypted data */
        module = fopen(p, "w");
		fwrite(module_data, 1, module_len, module);
        fclose(module);
        free(module_name);
        free(module_data);
    }
    return 0;
}

/*
 * instatiates a lua VM enclave for each new client.
 * Receives the code from the client, decrypt the code
 * execute it on the secure enclave and sends back the results
 * encrypted to the client.
 */
void *
spawn_lua_enclave(int n_socket)
{
    /* we have accepted our connecton, start ticking the timer */
    FILE *encrypted_file;
    sgx_status_t ret;                       /* sgx ecall return value           */
    int encrypted_code_len;                 /* encrypted len from the client    */
    char *buf;                              /* encrypted code for the client    */
    char fname[20];                         /* base lua code fname              */
    int val_result;                         /* result value of calls            */
    /* init the values */
    network_time = exec_time = 0.0f;
    (void)ret;
    (void)val_result;
    buf = NULL;
    encrypted_file = NULL;
#ifdef DEBUG
    fprintf(stdout, "-> Client connected, waiting for code!\n");
#endif
    clock_gettime(CLOCK_REALTIME, &tsgx_start);
    clock_gettime(CLOCK_REALTIME, &tsgx_stop);
    sgx_time += get_time_diff(tsgx_stop, tsgx_start)  / ns;;
    /*
	 * Setup up public and private keys with the client.
	 * Store the key in the Enclave, generate the 
	 * secret AES key and send it to the server
	 */
	l_setup_client_handshake(unique_eid, n_socket);
    while (1) {
    /* receive the code file from the client */
    buf = recv_file(n_socket, &encrypted_code_len);
#ifdef DEBUG
    if (!buf)
        goto cleanup;
    fprintf(stdout, "Code size = %d\n", encrypted_code_len);
#endif
    val_result = receive_modules(n_socket);
#ifdef DEBUG
    if (val_error(val_result, 0, LOCATION, "Failed to receive modules", 1))
        goto cleanup;
#endif
    /* prepare the base lua file */
    memset(fname, 0, 20);
    sprintf(fname, "%d.lua", n_socket);
    encrypted_file = fopen(fname, "w");
    /* write the encrypted code buffer into the base lua file */
    fwrite(buf, sizeof(char), encrypted_code_len, encrypted_file);
    fclose(encrypted_file);
    /* push the file name of the executable to sgx */
    clock_gettime(CLOCK_REALTIME, &tsgx_start);
	/* push the file name to lua. This will be the executable*/
    ret = ecall_push_arg(unique_eid, fname, strlen(fname));
    clock_gettime(CLOCK_REALTIME, &tsgx_stop);
    sgx_time += get_time_diff(tsgx_stop, tsgx_start) / ns;
#ifdef DEBUG
    if (val_error(ret, SGX_SUCCESS, LOCATION, "Failed to push executable file", 1))
        goto cleanup;
#endif
    clock_gettime(CLOCK_REALTIME, &texec_start);
	/* Start executing the code */
    execute_code_thread(unique_eid, n_socket);
    clock_gettime(CLOCK_REALTIME, &texec_stop);
    /*
     * Start taking the results of the remote execution 
     */
    exec_time = get_time_diff(texec_stop, texec_start) / ns;
    e2e_time += get_time_diff(texec_stop, te2e_start) / ns;   
    /* benchmarking mode + i want prints */
    if (disable_timer_print == 0) {
		/* print network as well */
		l_print_timers(1);
	}
#ifdef DEBUG
    /* cleanup the connection info */
cleanup:
#endif
	/* free resources here */
    if (buf)
        free(buf);
    buf = NULL;
    /* close the socket */
    close(new_socket);
	/* clean the pending file descriptors */
    ocall_clean_fd();
    }
    return NULL;
}
