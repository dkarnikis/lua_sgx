#define _DEFAULT_SOURCE
#include <arpa/inet.h>
#include <sys/socket.h>
#include <libgen.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <getopt.h>
#include <inttypes.h>
#include <time.h>
#include <sys/stat.h>
#include "tools.h"
#include "tweetnacl.h"
// Lua modules 
#include <lua.h>
#include <lauxlib.h>
#define KEY_SIZE 16
#define CHUNK_LEN 4096

typedef struct content Content;
void randombytes(unsigned char *x,unsigned long long xlen);

void
decrypt(unsigned char *key, Content encrypted_buffer, unsigned char *client_public_key, unsigned char *server_secret_key)
{
    unsigned char nonce[crypto_box_NONCEBYTES];
    unsigned char *encrypted, *message;
    long esize;
    Content c;
    randombytes(nonce, sizeof(nonce));
    memset(nonce, 0, crypto_box_NONCEBYTES);
    c = encrypted_buffer;
    memcpy(nonce, c.bytes, crypto_box_NONCEBYTES);
    esize = c.size - crypto_box_NONCEBYTES + crypto_box_BOXZEROBYTES;
    encrypted = malloc(esize);
    if (encrypted == NULL)
        perror("Malloc failed!");
    memset(encrypted, 0, crypto_box_BOXZEROBYTES);
    memcpy(encrypted + crypto_box_BOXZEROBYTES,
        c.bytes + crypto_box_NONCEBYTES, c.size - crypto_box_NONCEBYTES);
    // Equivalently, esize - crypto_box_BOXZEROBYTES
    free(c.bytes);
    // Output
    message = calloc(esize, sizeof(unsigned char));
    if (message == NULL)
        perror("Calloc failed!");
    // Encrypt
    crypto_box_open(message, encrypted, esize,
        nonce, client_public_key, server_secret_key);
    free(encrypted);
    memcpy(key, &message[crypto_box_ZEROBYTES], (int)(esize - crypto_box_ZEROBYTES));
    free(message);
}





void recv_shared_key(int sock, uint8_t *key, int size);
void send_client_public(int sock, uint8_t *key, int size);
void recv_number(int sock, int *num);



void usage(void);
void check_args(int port, char *server, char *input, int nom, int mc);




/*
 * decrypt the incoming code from the client using AES
 */
unsigned char *
code_decrypt(unsigned char *str, size_t len, unsigned char *encryption_key)
{
    unsigned char n[crypto_stream_NONCEBYTES];
    unsigned char *cipher;
    cipher = (unsigned char *)calloc(len, sizeof(unsigned char) + 1);
    memset(n, 0, crypto_stream_NONCEBYTES);
    crypto_stream_xor(cipher, str, len, n, encryption_key);
    cipher[len] = '\0';
    return cipher;
}

/*
 * Same function for encryption/decryption
 */
unsigned char *
encrypt_chunk(unsigned char *enc, size_t data_size, unsigned char *aes_key)
{
    size_t len, rx_bytes;
    unsigned char *plain_text, *cipher;
    len = CHUNK_LEN;
    rx_bytes = 0;
    plain_text = (unsigned char *)calloc(1, data_size);
    while (rx_bytes != data_size) {
        if ((rx_bytes + len) > data_size) {
            len = data_size - rx_bytes;
        }
        cipher =  code_decrypt(&enc[rx_bytes], len, aes_key);
        memcpy(&plain_text[rx_bytes], cipher, len);
        rx_bytes += len;
        cipher[len] = '\0';
#ifdef DEBUG
        printf("|%.*s|\n", len, cipher);
#endif
        free(cipher);
    }
    //printf("||||||%.*s||||||\n", data_size, plain_text);
    return plain_text;
}











    char *
lrecv_response(int sock, int *response_len)
{
    char *response;
    size_t tmp_bytes, rx_bytes;
#ifdef DEBUG
    fflush(stdout);
    printf("Waiting response\n");
#endif
    /* receive the response len of the lua vm */
    recv_number(sock, response_len);
#ifdef DEBUG
    printf("Got response\n");
#endif
    /* allocate the response buffer, add 8 bytes fixed to fix decryption warnings on valgrind */
    response = (char *)calloc(1, sizeof(char) * (*response_len + 8));
    /* receive the response buffer form the lua vm */
    tmp_bytes = 0;
    rx_bytes = 0;
    while ((tmp_bytes = read(sock, &response[rx_bytes], *response_len-rx_bytes)) > 0)
        rx_bytes += tmp_bytes;
    return response;
}

unsigned char *
recv_data(int *data_size, int socket_fd)
{
    unsigned char *data;
    int rx_bytes, tmp_bytes;
    rx_bytes = tmp_bytes = 0;
    read(socket_fd, data_size, sizeof(int));
    data = calloc(*data_size, sizeof(unsigned char));
    while (rx_bytes != *data_size) {
        //write(socket_fd, &var, sizeof(size_t));
        tmp_bytes = read(socket_fd, &data[rx_bytes], (*data_size-rx_bytes));
        rx_bytes += tmp_bytes;
    }
    return data;
}


unsigned char *
lhandshake(int sock)
{
    Content c1, c2;
    unsigned char *aes_key;
    aes_key = (unsigned char *)malloc(2 * KEY_SIZE * sizeof(unsigned char));
    unsigned char client_public_key[crypto_box_PUBLICKEYBYTES];
    unsigned char server_public_key[crypto_box_PUBLICKEYBYTES];
    unsigned char client_secret_key[crypto_box_SECRETKEYBYTES];
    memset(client_public_key, 0, crypto_box_PUBLICKEYBYTES);
    memset(client_secret_key, 0, crypto_box_SECRETKEYBYTES);
    memset(server_public_key, 0, crypto_box_PUBLICKEYBYTES);
   
    crypto_box_keypair(client_public_key, client_secret_key);
    /* send shared key */
    send_client_public(sock, client_public_key, crypto_box_PUBLICKEYBYTES);
    recv_shared_key(sock, server_public_key, crypto_box_PUBLICKEYBYTES);
    int a, b;
    a = b = 0;
    c1.bytes = recv_data(&a, sock);
    //__print_key("Encryption key", c1.bytes, c1.size);
    c2.bytes = recv_data(&b, sock);
    c1.size = a;
    c2.size = b;
    unsigned char enc_key1[KEY_SIZE];
    unsigned char enc_key2[KEY_SIZE];
    memset(enc_key1, '\0', KEY_SIZE);
    memset(enc_key2, '\0', KEY_SIZE);
    decrypt(enc_key1, c1, server_public_key, client_secret_key);
    decrypt(enc_key2, c2, server_public_key, client_secret_key);
    memcpy(&aes_key[0], enc_key1, KEY_SIZE);
    memcpy(&aes_key[16], enc_key2, KEY_SIZE);
    
    //__print_key("Encryption key", aes_key, KEY_SIZE * 2);

    return aes_key;
}

char *
ldecrypt(char *response, size_t response_len, unsigned char *aes_key)
{
    int i;
    return NULL;
}

int
lconnect(char *server_name, int server_port)
{
    struct sockaddr_in server_address;
    int enabled;                /* socket flag */
    int sock;
    enabled = 1;
    /* init the server */
    memset(&server_address, 0, sizeof(server_address));
    server_address.sin_family = AF_INET;
    /* creates binary representation of server name */
    inet_pton(AF_INET, server_name, &server_address.sin_addr);
    /* htons: port in network order format */
    server_address.sin_port = htons(server_port);
    /* open a stream socket */
    if ((sock = socket(AF_INET, SOCK_STREAM, 0)) < 0) {
        perror("could not create socket\n");
        exit(EXIT_FAILURE);
    }
    setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &enabled, sizeof(int));
    /* Connect to the server */
    if (connect(sock, (struct sockaddr*)&server_address,
                sizeof(server_address)) < 0) {
        perror("could not connect to server\n");
        exit(EXIT_FAILURE);
    }
#ifdef DEBUG
    printf("Connected to server: %s with port: %d\n", server_name, server_port);
    printf("Waiting Port\n");
#endif
    return sock;
}

    void
send_client_public(int sock, uint8_t *key, int size)
{
    if (write(sock, key, size) == -1) {
        perror("Error in sending public key\n");
        exit(EXIT_FAILURE);
    }
}

    void
send_int(int sock, int size)
{
    if (write(sock, &size, sizeof(int)) == -1) {
        perror("Error in sending encrypted code len\n");
        exit(EXIT_FAILURE);
    }
}

void
send_data(int socket_fd, unsigned char *data, int data_size)
{
    int rx_bytes, tmp_bytes;
    rx_bytes = tmp_bytes = 0;
    write(socket_fd, &data_size, sizeof(int));
    while (rx_bytes != data_size) {
        //write(socket_fd, &var, sizeof(size_t));
        tmp_bytes = write(socket_fd, &data[rx_bytes], (data_size-rx_bytes));
        //__print_key(&data[rx_bytes], data_size-rx_bytes);
        rx_bytes += tmp_bytes;
    }
}

/*
 * receive the shared key of the server
 */
    void
recv_shared_key(int sock, uint8_t *key, int size)
{
    if (read(sock, key, size) == -1){
        perror("Error in receiving server public key");
        exit(EXIT_FAILURE);
    }
}

/*
 * receive a number from a socket 
 */
    void
recv_number(int sock, int *num)
{
    if (read(sock, num, sizeof(int)) == -1) {
        perror("Error or timeout occured on recv");
        exit(EXIT_FAILURE);
    }
}


    int
get_file_size(FILE *file)
{
    int size;
    fseek(file, 0L, SEEK_END);
    size = ftell(file);
    fseek(file, 0L, SEEK_SET);
    return size;
}

void
lsend_code_encrypted(int sock, char *data, int size, unsigned char *aes_key)
{
    unsigned char *encrypted = encrypt_chunk(data, size, aes_key);
    send_data(sock, encrypted, size);
    free(encrypted);
}

void
lsend_file_code(int sock, char *fname, unsigned char *aes_key)
{
    FILE *code;
    int size;
    char *data;
    // read file contents
    code = fopen(fname, "r");
    if (code == NULL) {
        printf("Cannot open file\n");
        exit(EXIT_FAILURE);
    }
    // get file size
    size = get_file_size(code);
    // alloc the data and encrypted buffer
    data = (char *)calloc(1, (size) * sizeof(char));
    // copy file contents to buffer
    fread(data, sizeof(char), size, code);
    fclose(code);
    // we don't have a key, send plaintext
    if (aes_key == NULL)
        send_data(sock, data, size);
    else
        // send using the encryption key
        lsend_code_encrypted(sock, data, size, aes_key);
    send_data(sock, fname, strlen(fname));
}

    void
__print_key(char *str, uint8_t *key, int size)
{
    int i;
    printf("%s = ", str);
    for (i = 0; i < size; i++) {
        printf("%u", key[i]);
    }
    printf("\n");
}

static int lua_connect(lua_State* L)
{
    char *a = luaL_checkstring(L, 1);
    int n = luaL_checkinteger(L, 2);
    int mode = luaL_checkinteger(L, 3);
    int sock = lconnect(a, n);
    // are we using encryption
    send_int(sock, mode);
    lua_pushinteger(L, sock);
    return 1;
}

static int lua_handshake(lua_State* L)
{
    unsigned char *aes_key;
    int n = luaL_checkinteger(L, 1);
    aes_key = lhandshake(n);
    lua_pushlstring(L, aes_key, KEY_SIZE * 2);
    return 1;
}

static int lua_recv_response(lua_State* L)
{
    unsigned char *res;
    char *plain;
    int argc = lua_gettop(L);
    int b = 0;
    int a = luaL_checkinteger(L, 1);
    unsigned char *aes_key;
    res = lrecv_response(a, &b);
    // we don't have encryption
    if (argc == 1) {
        plain = res;
    } else {
        aes_key = luaL_checkstring(L, 2);
        plain = encrypt_chunk(res, b, aes_key);
    }
    //printf("%d %d\n", strlen(plain), b);
    //lua_pushstring(L, plain);
    lua_pushlstring(L, plain, b);
    return 1;
}

static int lua_send_module(lua_State* L)
{
    int argc = lua_gettop(L);
    int sock = luaL_checkinteger(L, 1);
    unsigned char *aes_key = NULL;
    // we don't have any module to send
    if (argc == 1) {
        send_int(sock, 0);
        return 0;
    } else 
        send_int(sock, 1);
    // fetch the encryption key;
    if (argc == 3)
        aes_key = luaL_checkstring(L, 3);
    // fetch the filename 
    char *fname = luaL_checkstring(L, 2);
    lsend_file_code(sock, fname, aes_key);
    return 0;
}

static int lua_close_socket(lua_State* L)
{
    int sock = luaL_checkinteger(L, 1);
    shutdown(sock, 2);
    close (sock);
    return 0;
}

static int lua_send_code(lua_State* L)
{
    int argc = lua_gettop(L);
    int sock = luaL_checkinteger(L, 1);
    char *data = strdup(luaL_checkstring(L, 2));
    unsigned char *aes_key = NULL;
    // we are not using encryption
    if (argc == 2) {
        send_data(sock, data, strlen(data));
    } else {
        aes_key = luaL_checkstring(L, 3);
        lsend_code_encrypted(sock, data, strlen(data), aes_key);
    }
    return 0;
}

static luaL_Reg const liblclientlib[] = {
    { "lconnect", lua_connect},
    { "lhandshake", lua_handshake},
    { "lsend_module", lua_send_module},
    { "lsend_code", lua_send_code},
    { "lclose_socket", lua_close_socket},
    { "lrecv_response", lua_recv_response},
    { 0, 0 }
};

#ifdef __RAPTOR_JIT__
    int 
    luaopen_liblclient(lua_State* L)
    {
        luaL_register(L, "foo", liblclientlib);
        return 1;
    }


#elif defined (__LUA_JIT__)
    int 
    luaopen_liblclient(lua_State* L)
    {
        luaL_register(L, "foo", liblclientlib);
        return 1;
    }
#else
    int 
    luaopen_liblclient(lua_State* L)
    {
        luaL_newlib(L, liblclientlib);
        return 1;
    }
#endif
