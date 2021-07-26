#include "funcs.h"
#include <stdio.h>
#include <sys/types.h>
#include <stdlib.h>
#include <err.h>
#include "nw.h"
#include "../Enclave/dh/tools.h"
#include "../Enclave/dh/tweetnacl.h"
#define ENCLAVE_FILE "enclave.signed.so"
#define LOCATION __LINE__,__FILE__,__func__

short keys_created = 0;
extern short local_execution;
double
timespec_to_ns(struct timespec tp)
{
    return ((double)tp.tv_sec / 1.0e-9) + (double)tp.tv_nsec;
}

double
get_time_diff(struct timespec a, struct timespec b)
{
    return (double)(timespec_to_ns(a) - timespec_to_ns(b));
}

/*
 * creates a file based on integer a.
 * Writes the buffer buf in the file
 * returns the new file name
 */
char *
write_bytes_to_file(int a, void *buf, int size)
{
    char *fname;
    FILE *encrypted_file;
    fname = (char *)calloc(1, 20);
    sprintf(fname, "%d.lua", a);
    encrypted_file = fopen(fname, "w");
    /* write the encrypted code buffer into the base lua file */
    fwrite(buf, 1, size, encrypted_file);
    fclose(encrypted_file);
    return fname;
}

/*
 * Prints a key contents
 * char *s is the type (Public or Private)
 */
void
print_key(const char *s, uint8_t *key, int size)
{
    int i;
    printf("%s: ", s);
    for (i = 0; i < size; i++)
        printf("%u", key[i]);
    printf("\n");
}

/* 
 * error checking functions
 */
void
serr(int l, const char *f, const char *fu, const char *fmt, int exit)
{
    fprintf(stderr, "%s line %d of file %s (function %s)\n", fmt, l, f, fu);
    if (exit == 1)
        perror("Error occured, closing sockets\n");
}

int
val_error(int a, int expected, int l, const char *f, const char *fu, const char *format, int exit)
{
    if (a != expected) {
        serr(l, f, fu, format, exit);
        return 1;
    }
    return 0;
}

/* 
 * same as above but compares the value
 */
int
valc_error(int a, int expected, int l, const char *f, const char *fu, const char *format, int exit)
{
    if (a <= expected) {
        serr(l, f, fu, format, exit);
        return 1;
    }
    return 0;
}

/* 
 * checks if ptr is null
 */
void
check_error(void *ptr, int l, const char *f, const char *fu, const char *format)
{
    if (ptr == NULL) {
        errx(1, "Mem Error: %s line %d of file %s (function %s)\n", format, l, f, fu);
        abort();
    }
}


sgx_enclave_id_t
l_setup_enclave()
{
    sgx_launch_token_t token = {0};
    sgx_enclave_id_t unique_eid;
    sgx_status_t ret;
    int updated;
    (void)ret;
    clock_gettime(CLOCK_REALTIME, &tsgx_start);
    /* spawn the new hardware enclave */
    ret = sgx_create_enclave(enclave_path, SGX_DEBUG_FLAG, &token,
            &updated, &unique_eid, NULL);
#ifdef DEBUG
    if (val_error(ret, SGX_SUCCESS, LOCATION, "Failed to create enclave", 1))
        abort();
#endif
    /* initialize lua VM arguments and stdio */
    ret = ecall_init(unique_eid, disable_execution_output, stdin, stdout, stdout);
#ifdef DEBUG
    val_error(ret, SGX_SUCCESS, LOCATION, "Failed to initialize lua arguments", 0);
#endif
#ifdef DEBUG
    val_error(ret, SGX_SUCCESS, LOCATION, "Failed to initialize lua arguments", 0);
#endif
    clock_gettime(CLOCK_REALTIME, &tsgx_stop);
    sgx_time = get_time_diff(tsgx_stop, tsgx_start) / ns;
    return unique_eid;
}

/*
 * Prints the usage message
 * Describe the usage of the new arguments you introduce
 */
void
usage(void)
{
    fprintf(stdout, "The file argument must be passed on either case as last parameter\n");
	fprintf(stdout,
	    "\n"
	    "Usage:\n"
	    "    app [-p port | -l] [-f] [-t] [-e] [-h]" 
	    "    assign_1 -h\n"
	);
	fprintf(stdout,
	    "\n"
	    "Options:\n"
	    " -p    port        Port for the server to listen to\n"
	    " -l    input_file  The file to execute on local execution mode\n"
        " -f    loops       Uses singe Lua VM instance for better perfomance: -1 = inf\n"
        " -t                Don't print timer statistics\n"
		" -e   enclave		The filepath of the enclave file, on not assigned, local path is set\n"
	    " -h                This help message\n"
	);
	exit(EXIT_FAILURE);
}

/*
 * On encryption mode, setup the handshake with the client(Setup SGX keys, send 
 * the public key to client, get the public key of client, store it to SGX). 
 * Generate the shared AES key based on the keys and send it back to client
 */
void
l_setup_client_handshake(sgx_enclave_id_t eid, int n_socket)
{
    sgx_status_t ret;
    int val_result;
    unsigned char client_public_key[crypto_box_PUBLICKEYBYTES];
    unsigned char server_public_key[crypto_box_PUBLICKEYBYTES];
    (void)val_result;
    (void)ret;
    memset(client_public_key, 0, crypto_box_PUBLICKEYBYTES);
    memset(server_public_key, 0, crypto_box_PUBLICKEYBYTES);
    clock_gettime(CLOCK_REALTIME, &tsgx_start);
    /* creates keys if we are on single enclave_instance */
    if (keys_created == 0) {// || single_enclave_instance == 0) {
        ret = ecall_gen_pkeys(eid);
#ifdef DEBUG
        if (val_error(ret, SGX_SUCCESS, LOCATION, "Failed to gen server keys", 1))
            goto cleanup;
        fprintf(stdout, "Recieving client key\n");
#endif
        keys_created = 1;
    }
    clock_gettime(CLOCK_REALTIME, &tsgx_stop);
    sgx_time += get_time_diff(tsgx_stop, tsgx_start) / ns;
    /* Receive the clients public Key */
    val_result = (int)recv_client_key(n_socket, client_public_key, crypto_box_PUBLICKEYBYTES);
#ifdef DEBUG
    if (val_error(val_result, crypto_box_PUBLICKEYBYTES, LOCATION, "Failed to recv Client public key", 1))
        goto cleanup;
    fprintf(stdout, "Received client key\n");
#endif
    clock_gettime(CLOCK_REALTIME, &tsgx_start);
    ret = ecall_register_client(eid, n_socket, client_public_key, crypto_box_PUBLICKEYBYTES);
    clock_gettime(CLOCK_REALTIME, &tsgx_stop);
    sgx_time += get_time_diff(tsgx_stop, tsgx_start) / ns;
#ifdef DEBUG
    if (val_error(ret, SGX_SUCCESS, LOCATION, "Failed to copy server public key", 1))
        goto cleanup;
#endif
    clock_gettime(CLOCK_REALTIME, &tsgx_start);
    ret = ecall_get_server_pkey(eid, server_public_key, crypto_box_PUBLICKEYBYTES);
    clock_gettime(CLOCK_REALTIME, &tsgx_stop);
    sgx_time += get_time_diff(tsgx_stop, tsgx_start) / ns;
#ifdef DEBUG
	fflush(stdout);
    if (val_error(ret, SGX_SUCCESS, LOCATION, "Failed to copy client public key", 1))
        goto cleanup;
    fprintf(stdout, "Sending server's pkey\n");
#endif
    val_result = (int)send_public_key(n_socket, server_public_key,
            crypto_box_PUBLICKEYBYTES);
#ifdef DEBUG
    if (val_error(val_result, crypto_box_PUBLICKEYBYTES, LOCATION, "Failed to send server public key", 1))
        goto cleanup;
#endif 
    clock_gettime(CLOCK_REALTIME, &tsgx_start);
    /* generate the aes key and send it to the client */
    ret = ecall_send_aes_key(eid, n_socket);   
    clock_gettime(CLOCK_REALTIME, &tsgx_stop);
    sgx_time += get_time_diff(tsgx_stop, tsgx_start) / ns;
#ifdef DEBUG
    if (val_error(ret, SGX_SUCCESS, LOCATION, "Failed to copy client public key", 1))
        goto cleanup;
    print_key("Client public Key: ", client_public_key, crypto_box_PUBLICKEYBYTES);
    print_key("Server public Key: ", server_public_key, crypto_box_PUBLICKEYBYTES);
#endif
	return NULL;
#ifdef DEBUG
cleanup:
	printf("Failed\n");
	abort();
#endif
}

/*
 * Legacy Shit
 */
void
l_print_timers(int print_nw)
{
    if (print_nw == 0) {
        /* E2E means from the start of main to the end of code */
        fprintf(stdout, "E2E: %f ", e2e_time);
        /* exec refers to exec only without sgx init */
        fprintf(stdout, "EXEC: %f ", exec_time);
        /* time required for the sgx to init a new enclave and pass the lua args */
        fprintf(stdout, "SGX: %f\n", sgx_time);
    } else {
        /* E2E means from the start of main to the end of code */
        fprintf(stdout, "E2E: %f\t", e2e_time);
        /* Network time */
        fprintf(stdout, "NW: %f\t", network_time);
        /* exec refers to exec only without sgx init */
        fprintf(stdout, "INIT: %f\t", sgx_time);
        /* exec only time */
        fprintf(stdout, "EXEC: %f\n", exec_time);
    }
}
