#include "nw.h"
#include "funcs.h"
#include <stdio.h>
#define LOCATION __LINE__,__FILE__,__func__
struct timespec tnw_start{0, 0}, tnw_stop{0, 0};
double network_time = 0.0f;

/*
 * write data to socket
 */
ssize_t 
l_write(int socket, void *data, int size)
{
	ssize_t d;
	double t;
    clock_gettime(CLOCK_REALTIME, &tnw_start);
    d = write(socket, data, size);
    clock_gettime(CLOCK_REALTIME, &tnw_stop);
	t = get_time_diff(tnw_stop, tnw_start) / ns; 
    network_time += t;
	return d;
}

/*
 * read data from socket to buffer
 */
ssize_t
l_read(int socket, void *data, int size)
{
    ssize_t d;
	double t;
    clock_gettime(CLOCK_REALTIME, &tnw_start);
    d = read(socket, data, size);
    clock_gettime(CLOCK_REALTIME, &tnw_stop);
	t = get_time_diff(tnw_stop, tnw_start) / ns; 
    network_time += t;
    return d;
}

int
l_create_socket(unsigned short int port)
{
    int welcome_socket, val_result, enable;
    struct sockaddr_in server_addr;
	(void)val_result;
    enable = 1;
    welcome_socket = socket(PF_INET, SOCK_STREAM, IPPROTO_TCP);
#ifdef DEBUG
    if (valc_error(welcome_socket, 0, LOCATION, "Service socket failed", 1))
        abort();
#endif
    setsockopt(welcome_socket, SOL_SOCKET, SO_REUSEADDR, &enable, sizeof(int));
    server_addr.sin_family = AF_INET;
    server_addr.sin_port = htons(port);
    server_addr.sin_addr.s_addr = INADDR_ANY;
    memset(server_addr.sin_zero, '\0', sizeof(server_addr.sin_zero));
    val_result = bind(welcome_socket, (struct sockaddr *) &server_addr, sizeof(server_addr));
#ifdef DEBUG
    if (val_error(val_result, 0, LOCATION, "Bind failed", 1))
        abort();
#endif
    val_result = listen(welcome_socket, 1);
#ifdef DEBUG
    if (val_error(val_result, 0, LOCATION, "Error on socket listen", 1) == 0)
        fprintf(stdout, "Listening to ports from = %d\n", welcome_socket);
#endif
    return welcome_socket;
}

int
l_accept(int welcome_socket)
{
    socklen_t addr_size;
    sockaddr_in client;
    int a;
    addr_size = sizeof(client);
    a = accept(welcome_socket, (struct sockaddr *) &client,
        &addr_size);
#ifdef DEBUG
    if (valc_error(a, 0, LOCATION, "Accept failed", 1))
        abort();
#endif
    return a;
}

ssize_t
send_number(int n_socket, int number)
{
    return l_write(n_socket, &number, sizeof(int));
}

ssize_t
recv_num(int n_socket, int *number)
{
    ssize_t res;
	res = l_read(n_socket, number, sizeof(int));
#ifdef DEBUG
    if (res == -1)
        abort();
#endif
    return res;
}

ssize_t
recv_client_key(int n_socket, uint8_t *key, int size)
{
	return l_read(n_socket, key, size);
}

ssize_t
send_public_key(int n_socket, uint8_t *key, int size)
{
	return l_write(n_socket, key, size);
}

ssize_t
recv_data(int n_socket, char *buffer, int number)
{
    int rx_bytes;
    int tmp_bytes;
    rx_bytes = 0;
    tmp_bytes = 0;
    while (rx_bytes < number) {
        tmp_bytes = (int)l_read(n_socket, &buffer[rx_bytes], (number-rx_bytes));
#ifdef DEBUG
        if (valc_error(tmp_bytes, 0, LOCATION, "Error receiving packet", 1))
            return -1;
#endif
        rx_bytes += tmp_bytes;
    }
    return rx_bytes;
}

char *
recv_file(int n_socket, int *s)
{   
    clock_gettime(CLOCK_REALTIME, &te2e_start);
    char *string;
    ssize_t b;
#ifdef DEBUG
    int res;
#endif
    b = recv_num(n_socket, s);
    if (b == 0)
        return NULL;
    string = (char *)calloc(1, ((int) *s) * sizeof(char) + 1);
#ifdef DEBUG
    check_error(string, LOCATION, "Failed to allocate memory");
    res = 
#endif
    recv_data(n_socket, string, *s);
#ifdef DEBUG
    if (res == -1)
        abort();
#endif
    return string;
}

/* 
 * function that sends encrypted data to a socket 
 */
void
ocall_send_packet(int n_socket, unsigned char *pkt, size_t len)
{
    ssize_t rx_bytes;
    ssize_t tmp_bytes;
    rx_bytes = 0;
    tmp_bytes = 0;
    if (send_number(n_socket, (int)len) == -1) {
        check_error(NULL, LOCATION, "Failed to send packet to the client");
        exit(EXIT_FAILURE);
    }
    while (rx_bytes != (ssize_t)len) {
        tmp_bytes = l_write(n_socket, &pkt[rx_bytes], (int)(len-rx_bytes));
        rx_bytes += tmp_bytes;
    }
}
