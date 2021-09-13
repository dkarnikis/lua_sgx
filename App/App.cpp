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
void close_open_fds(int s);
char *code_file = NULL;
/*
 * The enclave id
 */
sgx_enclave_id_t unique_eid;
int welcome_socket;
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
 * Optimized mode for lua. Uses the same enclave for all executions
 */
void *spawn_lua_og(int n_socket);
extern "C" int lua_main(int argc, char **argv);

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
send_timers(int n_socket)
{
    char timer_data[100];
    memset(timer_data, '\0', 100);
    sprintf(timer_data, "%.3f %.3f %.3f %.3f", e2e_time, network_time, sgx_time, exec_time);
    ocall_send_packet(n_socket, (unsigned char *)timer_data, strlen(timer_data));
}

int
main (int argc, char **argv)
{
    sgx_status_t ret;
    short unsigned int server_port; /* port that the daemon will listen to  */
    int opt;                        /* var for parsing args                 */
    char *input_file;               /* the file to open for execution       */
    int encryption_mode;
	(void)(ret);
    encryption_mode = 0;
    input_file = NULL;
    server_port = 0;
    sgx_time = 0.0f;
    code_file = strdup("code.lua");
    /*
     * Get arguments
     */
    while ((opt = getopt(argc, argv, "p:h")) != -1) { 
        switch (opt) {
            case 'p':
                server_port = (short unsigned int)atoi(optarg);
                break;
            case 'h':
            default:
                usage();
        }
    }
	// spawn our socket
	welcome_socket = l_create_socket(server_port);
start:
    // accept the new connection
    new_socket = l_accept(welcome_socket);
    recv_num(new_socket, &encryption_mode);
    // execute the code
    if (encryption_mode == 0) {
        // execute on the lua vm without SGX enclave
        spawn_lua_og(new_socket);
        close_open_fds(welcome_socket);
        goto start;
    } else if (encryption_mode == 1) {
        unique_eid = l_setup_enclave();
        // sgx opts with encryption
        sgx_time = 0;
        spawn_lua_enclave(new_socket, 0);
        //ecall_close_lua_state(unique_eid);
        sgx_destroy_enclave(unique_eid);
        close_open_fds(welcome_socket);
        goto start;
    } else if (encryption_mode == 2) {
        // sgx local without encryption
        spawn_lua_enclave(new_socket, 1);
        close_open_fds(welcome_socket);
        goto start;
    }
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
    int module_len;
    int modules;
    int module_name_len;
    FILE *module;
    char *buffer, *buf;
    module_len = modules = module_name_len = 0;
    // modules count
    recv_num(n_socket, &modules);
    if (modules == 0)
        return 0;
    buf = recv_file(n_socket, &module_len);
    // receive module name
    recv_num(n_socket, &module_name_len);
    // allocate the filename
    buffer = (char *)calloc(1, module_name_len);
    // receive the module name
    recv_data(n_socket, buffer, module_name_len);
    module = fopen(buffer, "w");
    fwrite(buf, 1, module_len, module);
    fclose(module);
    free(buf);
    free(buffer);
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
    FILE *execution_request;
    sgx_status_t ret;                       // sgx ecall return value
    int code_len;                           // encrypted len from the client
    char *buf;                              // encrypted code for the client
    int val_result;                         // result value of calls
    /* init the values */
    network_time = exec_time = 0.0f;
    (void)ret;
    (void)val_result;
    buf = NULL;
    execution_request = NULL;
#ifdef DEBUG
    fprintf(stdout, "\t-> Client connected, waiting for code!\n");
#endif
    // setup secure communication on encrypted session
    if (local_mode == 0)
        l_setup_client_handshake(unique_eid, n_socket);
    val_result = receive_modules(n_socket);
    e2e_time = 0.0f;
    while (1) { 
        buf = recv_file(n_socket, &code_len);
        if (buf == NULL)
            break;
        // on local execution, setup enclave clean
        if (local_mode == 1) {
            clock_gettime(CLOCK_REALTIME, &tsgx_start);
            close_open_fds(welcome_socket);
            unique_eid = l_setup_enclave();
            clock_gettime(CLOCK_REALTIME, &tsgx_stop);
            sgx_time = get_time_diff(tsgx_stop, tsgx_start) / ns;
        } else
            sgx_time = 0.0f;
        network_time = 0.0f;
        // receive the code file$
        execution_request = fopen(code_file, "w");
        // write the encrypted code buffer into the base lua file
        fwrite(buf, sizeof(char), code_len, execution_request);
        fclose(execution_request);
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
        free(buf);
        l_print_timers(1);
        send_timers(n_socket);
    }
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
    network_time = exec_time = 0.0f;
    (void)val_result;
    FILE *file;
    buf = NULL;
    file = NULL;
    // receive the dependency modules for this execution
    val_result = receive_modules(n_socket);
#ifdef DEBUG
    if (val_error(val_result, 0, LOCATION, "Failed to receive modules", 1))
        goto cleanup;
#endif
    e2e_time = 0;
    while (1) {
        // receive the code file
        buf = recv_file(n_socket, &code_len);
        if (!buf)
            break;
        network_time = 0;
        sgx_time = 0;

        /* receive the code file from the client */
#ifdef DEBUG
        if (!buf)
            goto cleanup;
        fprintf(stdout, "Code size = %d\n", code_len);
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
        lua_main(2, argv);
        // Start taking the results of the remote execution 
        // read the output data
        output_file = fopen("output", "r");
        output_size = ocall_get_file_size(output_file);
        output_data = (char *)calloc(1, output_size + 1);
        // read the output data of the execution
        (void)!fread(output_data, 1, output_size, output_file);
        fclose(output_file);
        ocall_send_packet(n_socket, (unsigned char *)output_data, output_size + 1);
        clock_gettime(CLOCK_REALTIME, &texec_stop);
        // clean the buffers
        free(buf);
        free(output_data);
        free(argv[0]);
        exec_time = get_time_diff(texec_stop, texec_start) / ns;
        e2e_time = get_time_diff(texec_stop, te2e_start) / ns;   
        l_print_timers(1);
        send_timers(n_socket);
    }
    goto end;
#ifdef DEBUG
cleanup:
    check_error(NULL, __LINE__, __FILE__, __FUNCTION__, "error occured\n");
#endif
end:
    close(n_socket);
    return NULL;
}
