#ifndef NW_H
#define NW_H
#include <sys/types.h>
#include <netdb.h>
#include <sys/socket.h>
#include <sys/param.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <stdlib.h>  
#include <time.h>
#include <string.h>
#include "sgx_urts.h"

ssize_t l_write(int socket, void *data, int size);
ssize_t l_read(int socket, void *data, int size);
int l_create_socket(unsigned short int port);
int l_accept(int welcome_socket);
ssize_t recv_number(int socket, int *number);
ssize_t recv_client_key(int socket, uint8_t *key, int size);
ssize_t send_public_key(int socket, uint8_t *key, int size);
ssize_t recv_data(int socket, char *buffer, int number);
ssize_t send_number(int socket, int number);
char *recv_file(int socket, int *s);   




extern double network_time;

struct client_info {
    char hoststr[NI_MAXHOST];
    char portstr[NI_MAXSERV];  
    short unsigned int free_port;
    sgx_launch_token_t token = {0};
    sgx_enclave_id_t eid;
};



#endif
