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
#include "../Enclave/dh/tools.h"
#include "../Enclave/dh/tweetnacl.h"
#include "funcs.h"
#include "nw.h"


#include "lua_lib/lprefix.h"
#include "lua_lib/lua.h"
#include "lua_lib/lauxlib.h"
#include "lua_lib/lualib.h"


#define LOCATION __LINE__,__FILE__,__func__
char code_file[20];
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
void *spawn_lua_og(int n_socket);

void
execute_code_thread(long unsigned int eid, int n_socket, int local_exec)
{
    sgx_status_t ret;
    (void)(ret);
    ret = ecall_execute(eid, n_socket, local_exec);
#ifdef DEBUG
    val_error(ret, SGX_SUCCESS, LOCATION, "Failed to execute lua code", 0);
    fprintf(stdout, "-> Code executed, results sent to the client\n");
    fprintf(stdout, "-> Connections with the client terminated\n");
#endif
}


void
send_timers(char timer_data[100], int n_socket)
{
    memset(timer_data, '\0', 100);
    sprintf(timer_data, "%.3f %.3f %.3f %.3f", e2e_time, network_time, sgx_time, exec_time);
    ocall_send_packet(timer_data, 100, n_socket);
}

extern "C" int lua_main(int argc, char **argv, int deo);
int
main (int argc, char **argv)
{
    sgx_status_t ret;
    short unsigned int server_port; /* port that the daemon will listen to  */
    int opt;                        /* var for parsing args                 */
    char *input_file;               /* the file to open for execution       */
    int encryption_mode = 0;
	int welcome_socket;
    /* init */
	(void)(ret);
    disable_execution_output = 0;
    input_file = NULL;
    server_port = 0;
    /* init the exec time values */
    sgx_time = 0.0f;
    memset(code_file, '\0', 20);
    sprintf(code_file, "code.lua");
    /*
     * Get arguments
     */
    while ((opt = getopt(argc, argv, "p:e:tidh")) != -1) { 
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
                server_port = (short unsigned int)atoi(optarg);
                break;
            case 'h':
            default:
                usage();
        }
    }
	if (enclave_path == NULL)
		enclave_path = strdup("enclave.signed.so");
#ifdef DEBUG
	// check if enclave file do not exist
	int i = access(enclave_path, F_OK);
	if (i == -1) {
		perror("Invalid enclave path");
		abort();
	}
#endif
	// spawn our socket
	welcome_socket = l_create_socket(server_port);
start1:
//    clock_gettime(CLOCK_REALTIME, &tsgx_start);
    unique_eid = l_setup_enclave();
//    clock_gettime(CLOCK_REALTIME, &tsgx_stop);
//    sgx_time = get_time_diff(tsgx_stop, tsgx_start) / ns;
start:
    // accept the new connection
    new_socket = l_accept(welcome_socket);
    recv_num(new_socket, &encryption_mode);
    // execute on the SGX vm
    if (encryption_mode == 0) {
        // execute on the lua vm
        spawn_lua_og(new_socket);
        goto start;
    } else if (encryption_mode == 1) {
        sgx_time = 0;
        spawn_lua_enclave(new_socket, 0);
        goto start;
    } else if (encryption_mode == 2) {
        spawn_lua_enclave(new_socket, 1);
        goto start1;
    }
    free(input_file);
    free(enclave_path);
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
    recv_num(n_socket, &number_of_modules);
    for (i = 0; i < number_of_modules; i++){
        module_name = module_data = NULL;
        /* got the module size */
        recv_num(n_socket, &module_len);
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
spawn_lua_enclave(int n_socket, int local_mode)
{
    /* we have accepted our connecton, start ticking the timer */
    FILE *encrypted_file;
    sgx_status_t ret;                       /* sgx ecall return value           */
    int encrypted_code_len;                 /* encrypted len from the client    */
    char *buf;                              /* encrypted code for the client    */
    int val_result;                         /* result value of calls            */
    char timer_data[100];
    /* init the values */
    network_time = exec_time = 0.0f;
    (void)ret;
    (void)val_result;
    buf = NULL;
    encrypted_file = NULL;
#ifdef DEBUG
    fprintf(stdout, "-> Client connected, waiting for code!\n");
#endif
    /*
	 * Setup up public and private keys with the client.
	 * Store the key in the Enclave, generate the 
	 * secret AES key and send it to the server
	 */
    if (local_mode == 0) {
        l_setup_client_handshake(unique_eid, n_socket);
    }
    e2e_time = 0;
    while (buf = recv_file(n_socket, &encrypted_code_len)) { 
        if (local_mode == 1) {
            clock_gettime(CLOCK_REALTIME, &tsgx_start);
            unique_eid = l_setup_enclave();
            clock_gettime(CLOCK_REALTIME, &tsgx_stop);
            sgx_time = get_time_diff(tsgx_stop, tsgx_start) / ns;
        } else {
            sgx_time = 0;
        }
        network_time = 0;

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
        encrypted_file = fopen(code_file, "w");
        /* write the encrypted code buffer into the base lua file */
        fwrite(buf, sizeof(char), encrypted_code_len, encrypted_file);
        fclose(encrypted_file);
        clock_gettime(CLOCK_REALTIME, &texec_start);
        // Start executing the code
        execute_code_thread(unique_eid, n_socket, local_mode);
        // on local, destroy the enclave and get time
        if (local_mode == 1) {
            clock_gettime(CLOCK_REALTIME, &tsgx_start);
            sgx_destroy_enclave(unique_eid);
            clock_gettime(CLOCK_REALTIME, &tsgx_stop);
            sgx_time += get_time_diff(tsgx_stop, tsgx_start) / ns;
        }
        clock_gettime(CLOCK_REALTIME, &texec_stop);
        // Start taking the results of the remote execution 
        exec_time = get_time_diff(texec_stop, texec_start) / ns;
        e2e_time = get_time_diff(texec_stop, te2e_start) / ns;   
        if (disable_timer_print == 0) {
            /* print network as well */
            l_print_timers(1);
        }
        send_timers(timer_data, n_socket);
        ocall_clean_fd();
    }
#ifdef DEBUG
    /* cleanup the connection info */
cleanup:
#endif
    close(new_socket);
    return NULL;
}

/*
 * instatiates a lua VM enclave for each new client.
 * Receives the code from the client, decrypt the code
 * execute it on the secure enclave and sends back the results
 * encrypted to the client.
 */
void *
spawn_lua_og(int n_socket)
{
    int code_len;                 /* encrypted len from the client    */
    char *buf;                              /* encrypted code for the client    */
    int val_result;                         /* result value of calls            */
    FILE *output_file;
    size_t output_size;
    char *output_data;
    /* init the values */
    network_time = exec_time = 0.0f;
    (void)val_result;
    FILE *file;
    char timer_data[100];
    buf = NULL;
    file = NULL;
    e2e_time = 0;
    while (buf = recv_file(n_socket, &code_len)) { 
        network_time = 0;
        sgx_time = 0;

        /* receive the code file from the client */
#ifdef DEBUG
        if (!buf)
            goto cleanup;
        fprintf(stdout, "Code size = %d\n", code_len);
#endif
        val_result = receive_modules(n_socket);
#ifdef DEBUG
        if (val_error(val_result, 0, LOCATION, "Failed to receive modules", 1))
            goto cleanup;
#endif
        char *argv[3];
        argv[0] = strdup("lua");
        argv[1] = code_file;
        argv[2] = NULL;
        file = fopen(code_file, "w");
        // write the encrypted code buffer into the base lua file
        fwrite(buf, sizeof(char), code_len, file);
        fclose(file);
        clock_gettime(CLOCK_REALTIME, &texec_start);
        // Start executing the code
        lua_main(2, argv, disable_execution_output);
        // Start taking the results of the remote execution 
        // read the output data
        output_file = fopen("output", "r");
        output_size = ocall_get_file_size(output_file);
        output_data = (char *)calloc(1, output_size + 1);
        fread(output_data, 1, output_size, output_file);
        fclose(output_file);
        ocall_send_packet(output_data, output_size + 1, n_socket);
        clock_gettime(CLOCK_REALTIME, &texec_stop);
        // construct the timer data 
        free(buf);
        free(output_data);
        free(argv[0]);
        exec_time = get_time_diff(texec_stop, texec_start) / ns;
        e2e_time = get_time_diff(texec_stop, te2e_start) / ns;   
        if (disable_timer_print == 0) {
            /* print network as well */
            l_print_timers(1);
        }
        send_timers(timer_data, n_socket);
    }
#ifdef DEBUG
cleanup:
#endif
    close(n_socket);
    return NULL;
}
