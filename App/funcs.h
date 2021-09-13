#ifndef FUNCS_H
#define FUNCS_H
#include <time.h>
#include <stdint.h>
#include "sgx_urts.h"
#include "sgx_defs.h"
#include "Enclave_u.h"

#define ns 1000000000
double timespec_to_ns(struct timespec tp);
double get_time_diff(struct timespec a, struct timespec b);
char *write_bytes_to_file(int a, void *buf, int size);
void print_key(const char *s, uint8_t *key, int size);
void serr(int l, const char *f, const char *fu, const char *fmt, int exit);
int val_error(int a, int expected, int l, const char *f, const char *fu, const char *format, int exit);
int valc_error(int a, int expected, int l, const char *f, const char *fu, const char *format, int exit);
void check_error(void *ptr, int l, const char *f, const char *fu, const char *format);
sgx_enclave_id_t l_setup_enclave();
void *service_daemon(struct thread_data *data);
void usage(void);
void check_args(int port, short local_exec, char *input_file);
void ocall_clean_fd(void);
void *spawn_lua_enclave(int s, int le);

sgx_enclave_id_t l_setup_local_enclave(int argc, char **argv, int i);
void l_setup_client_handshake(sgx_enclave_id_t eid, int socket);
void l_print_timers(int print_nw);
extern double sgx_time, e2e_time, exec_time;
extern timespec tsgx_start, tsgx_stop, te2e_start, te2e_stop, texec_start, texec_stop;
extern char *enclave_path;

#endif
