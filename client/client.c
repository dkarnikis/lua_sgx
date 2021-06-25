#define _DEFAULT_SOURCE
#include <arpa/inet.h>
#include <sys/socket.h>
#include <openssl/rand.h>
#include <libgen.h>
#include <openssl/conf.h>
#include <openssl/evp.h>
#include <openssl/err.h>
#include <openssl/crypto.h>
#include <openssl/aes.h>
#include <openssl/rsa.h>
#include <openssl/modes.h>
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
#include "commands.h"
uint8_t secret[16];         /* the shared encryption key */
struct ctr_state
{
    unsigned char ivec[16];
    unsigned int num;
    unsigned char ecount[16];
};

struct ctr_state state;
void output_key(char *str, unsigned char key[], int key_size);
unsigned char iv[16] = {5};
unsigned char aes_key[16] = {0};
unsigned char *decrypt(unsigned char *key, Content encrypted_buffer, unsigned char *client_public_key, unsigned char *server_secret_key);
void init_ctr(struct ctr_state *state, const unsigned char iv[16]);
int fencrypt(char *text, char *cipher, const unsigned char *enc_key, struct ctr_state *state, unsigned int buffer_size);
void usage(void);
void check_args(int port, char *server, char *input, int nom, int mc);

    void
handle_openssl_error(void)
{
    ERR_print_errors_fp(stderr);
    abort();
}

    void
send_client_public(int sock, uint8_t *key, int size)
{
    if(write(sock, key, size) == -1) {
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
send_data(int sock, char *data, int size)
{
    int sent;
    int t;
    sent = t = 0;
    while (sent != size) {
        t = write(sock, &data[sent], size-sent);
        if (t == -1)
            abort();
        sent += t;
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
fdecrypt(unsigned int len, char *cipher, char *text, const unsigned char *enc_key, 
        struct ctr_state *state)
{   
    AES_KEY key;
    unsigned char indata[AES_BLOCK_SIZE]; 
    unsigned char outdata[AES_BLOCK_SIZE];
    int offset;
    memset(indata, 0, AES_BLOCK_SIZE);
    memset(outdata, 0, AES_BLOCK_SIZE);
    memset(&key, 0, sizeof(AES_KEY));
    offset = 0;
    if (AES_set_encrypt_key(enc_key, 128, &key) < 0){
        fprintf(stderr, "Could not set decryption key.");
        exit(1);
    }
    while (1) {
        memcpy(indata, cipher+offset, AES_BLOCK_SIZE);  
        CRYPTO_ctr128_encrypt(indata, outdata, AES_BLOCK_SIZE, &key, state->ivec, 
                state->ecount, &state->num, (block128_f)AES_encrypt);
        memcpy(text+offset, outdata, AES_BLOCK_SIZE); 
        offset = offset+AES_BLOCK_SIZE;
        if (offset > len){
            break;
        }
    }
    return offset;
}

/*
 * Initialize the iv
 */
    void
init_ctr(struct ctr_state *state, const unsigned char iv[16])
{
    /* 
     * aes_ctr128_encrypt requires 'num' and 'ecount' set to zero on the
     * first call. 
     */
    state->num = 0;
    memset(state->ecount, 0, 16);
    /* Copy IV into 'ivec' */
    memcpy(state->ivec, iv, 16);
}

/*
 * performs encryption on plaintext and returns the size of encrypted bytes
 */
    int
fencrypt(char* text, char* cipher, const unsigned char* enc_key, struct ctr_state* state, unsigned int buffer_size)
{
    init_ctr(state, iv);
    AES_KEY key;
    unsigned int offset;
    unsigned char indata[AES_BLOCK_SIZE];
    unsigned char outdata[AES_BLOCK_SIZE];
    memset(indata, 0, AES_BLOCK_SIZE);
    memset(outdata, 0, AES_BLOCK_SIZE);
    memset(&key, 0, sizeof(AES_KEY));
    offset = 0;
    /* Initializing the encryption KEY */
    if (AES_set_encrypt_key(enc_key, 128, &key) < 0){
        printf("Error Could not set encryption key.");
        exit(EXIT_FAILURE);
    }
    while(1){
        memcpy(indata, text+offset, AES_BLOCK_SIZE);
        CRYPTO_ctr128_encrypt(indata, outdata, AES_BLOCK_SIZE, &key, state->ivec,\
                state->ecount, &state->num, (block128_f)AES_encrypt);
        memcpy(cipher+offset, outdata, AES_BLOCK_SIZE);
        offset=offset+AES_BLOCK_SIZE;
        if (offset > buffer_size){
            break;
        }
    }
    return offset;
}

    void
usage()
{
    printf(
            "\n"
            "Usage:\n"
            "   app -p port -s server_ip -i code [-e -r -w][a]\n"
            "   app -h\n"
          );
    printf(
            "\n"
            "Options:\n"
            " -p    port    Port for the server to listen to\n"
            " -s    ip      The ip of the server to connect\n" 
            " -i    file    The code to send to the server\n" 
            " -n    num     The number of modules to provide\n" 
            " -m    files   The provided modules code\n" 
            " -r			Loads the keys from keys.txt\n"
            " -w			Writes the keys to keys.txt\n"
            " -e            Encrypted mode\n" 
            " -h            This help message\n"
          );
    exit(EXIT_FAILURE);
    abort();
}

/*
 * check the validity of arguments
 */
    void
check_args(int port, char *server, char *input, int nom, int mc)
{
    if(port <= 0){
        fprintf(stdout, "Port number must be positive\n");
        usage();
    }
    if(!server){
        fprintf(stdout, "Server cannot be empty\n");
        usage();
    }
    if(!input){
        fprintf(stdout, "Input file cannot be empty\n");
        usage();
    }
    if(nom > 0 && mc != nom){
        fprintf(stdout, "Number of modules must be the same with the number of modules provides\n");
        usage();   
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
send_code_to_vm(int sock, char *string)
{
    FILE *code;
    int size;
    char *data;
    char *encrypted;
    int a, l;
    unsigned int counted, copied;
    a = l = 0;
    counted = copied = 0;
    /* reinit the aes keys and ciphrers */
    memset(&state, 0, sizeof (struct ctr_state));
    memset(iv, '5', 16);
    init_ctr(&state, iv);
    /* read file contents */
    code = fopen(string, "r");
    if (code == NULL) {
        printf("Cannot open file\n");
        exit(EXIT_FAILURE);
    }
    /* get file size */
    size = get_file_size(code);
    /* alloc the data and encrypted buffer */
    data = (char *)calloc(1, (size + 16) * sizeof(char));
    encrypted = (char *) calloc(1, (size + 16) * sizeof(char));
    /* copy file contents to buffer */
    fread(data, sizeof(char), size, code);
    fclose(code);
    copied = 0;
    counted = size;
#define MAX_COPY_SIZE BUFSIZ -1
    if (counted > MAX_COPY_SIZE) {
        while (counted > MAX_COPY_SIZE) {
            a =+ fencrypt(&data[l], &encrypted[copied] , aes_key, &state, MAX_COPY_SIZE);
            //printf("Writing (%d-%d)\n", l, MAX_COPY_SIZE+l);
            copied += MAX_COPY_SIZE+1;
            l+= MAX_COPY_SIZE + 1;
            counted -= MAX_COPY_SIZE;
        }
        a += fencrypt(&data[l], &encrypted[l], aes_key, &state, counted);
    } else {
        a += fencrypt(&data[0], &encrypted[0], aes_key, &state, counted);
    }
#ifdef DEBUG
    printf("Bytes to send = %d\n", counted);
#endif 
    if (counted > MAX_COPY_SIZE){}
    else
        a = size;
    send_int(sock, a);
#ifdef DEBUG
    printf("Sending %d\n", size);
#endif
    send_data(sock, encrypted, a);
}

    void
send_encrypted_string(int sock, char *string)
{
#if defined(DEBUG)
    printf("Opening %s\n", string);
#endif
    char buffer[2048];
    memset(buffer, 0, 2048);
    buffer[0] = '@';
    memcpy(&buffer[1], string, strlen(string));
    buffer[0 + strlen(string) + 1] = '@';
    buffer[0 + strlen(string) + 1 + 1] = '\0';
    write(sock, buffer, 2048);
    //send_data(sock, string, strlen(string) + 1);
}

    void
print_key(char *str, uint8_t *key, int size)
{
    int i;
    printf("%s = ", str);
    for (i = 0; i < size; i++) {
        printf("%u", key[i]);
    }
    printf("\n");
}

    int 
RNG(uint8_t *dest, unsigned size) 
{
    unsigned i;
    for (i = 0; i < size; i++) {
        dest[i] = rand();
    }
    return 1;
}

    int
main(int argc, char **argv)
{
    char *server_name;          /* server to send the lua           */
    char *response;             /* the encrypted response           */
    char *file_name;            /* the filename                     */
    char **module_array;        /* the module filename array        */
    char *response_plain;       /* the decrypted response           */
    int response_len;           /* the len of the reponse   data    */
    int enabled;                /* socket flag                      */
    int i;                      /* counter                          */
    int module_counter;         /* how many counters do we send     */
    int number_of_modules;      /* module counter                   */
    int server_port;            /* server port to connect to        */
    int sock;                   /* socket descriptor                */
    int opt;                    /* used for getopt                  */
    int tmp_bytes, rx_bytes;
    Content c;
    struct sockaddr_in server_address;
    unsigned char client_public_key[crypto_box_PUBLICKEYBYTES];
    unsigned char server_public_key[crypto_box_PUBLICKEYBYTES];
    unsigned char client_secret_key[crypto_box_SECRETKEYBYTES];
    /* init */
    module_array = NULL;
    enabled = 1;
    module_counter = 0;
    number_of_modules = 0;
    response_len = 0;
    server_port = 0;
    file_name = NULL;
    server_name = NULL;
    memset(client_public_key, 0, crypto_box_PUBLICKEYBYTES);
    memset(client_secret_key, 0, crypto_box_SECRETKEYBYTES);
    memset(server_public_key, 0, crypto_box_PUBLICKEYBYTES);
    srand(time(0));
    while ((opt = getopt(argc, argv, "p:s:i:n:m:h")) != -1){
        switch(opt) {
            case 'p':
                server_port = atoi(optarg);
                break;
            case 's':
                server_name = strdup(optarg);
                break;
            case 'i':
                file_name = strdup(optarg);
                break;
            case 'n':
                number_of_modules = atoi(optarg);
                module_array = (char **)calloc(number_of_modules, sizeof(char *));
                break;
            case 'm':
                if(number_of_modules == -1)
                    usage();
                module_array[module_counter] = strdup(optarg);
                module_counter++;
                break;
            case 'h':
            default:
                usage();
        }
    }
    /* check arguments */
    check_args(server_port, server_name, file_name, number_of_modules, module_counter);
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
    /* generate the keys please */
    crypto_box_keypair(client_public_key, client_secret_key);
    /* send shared key */
    send_client_public(sock, client_public_key, crypto_box_PUBLICKEYBYTES);
#ifdef DEBUG
    print_key("Public Key: ", client_public_key, crypto_box_PUBLICKEYBYTES);
#endif
    /* receive shared key */
    recv_shared_key(sock, server_public_key, crypto_box_PUBLICKEYBYTES);
#ifdef DEBUG
    printf("Received server pkey\n");
#endif
    /* receive the keysize */
    read(sock, &i, sizeof(int));
    c.size = i;
    /* allocate the buffer to store the key */
    c.bytes = calloc(1, c.size);
    /* receive shared key */
    read(sock, c.bytes, c.size);
    decrypt(aes_key, c, server_public_key, client_secret_key);
    /* send the encrypted file */
    send_code_to_vm(sock, file_name);
#ifdef DEBUG
    /* send the module number to the server */
    printf("Number of modules to send: " "%d\n", number_of_modules);
#endif
    send_int(sock, number_of_modules);
    /* send the modules to the server */
    for (i = 0; i < number_of_modules;i++){
        char *bob = strdup(module_array[i]);
        send_code_to_vm(sock, bob);
#if DEBUG
        printf("Sending module %s\n", bob);
#endif
        send_encrypted_string(sock, basename(bob));
        free(bob);
    }
#ifdef DEBUG
    fflush(stdout);
    printf("Waiting response\n");
#endif
    /* receive the response len of the lua vm */
    recv_number(sock, &response_len);
#ifdef DEBUG
    printf("Got response\n");
#endif
    /* allocate the response buffer */
    response = (char *)calloc(1, sizeof(char) * (response_len + 1));
    /* receive the response buffer form the lua vm */
    tmp_bytes = 0;
    rx_bytes = 0;
    while ((tmp_bytes = read(sock, &response[rx_bytes], response_len-rx_bytes)) > 0) {
        rx_bytes += tmp_bytes;
    }
    /* reinit the aes keys and ciphrers */
    memset(&state, 0, sizeof (struct ctr_state));
    memset(iv, '5', 16);
    init_ctr(&state, iv);
    /* allocate space for the decrypted results */
    /* decrypt the data */
    response_plain = (char *)calloc(1, sizeof(char) * (response_len + 16));
    fdecrypt(response_len, response, response_plain, aes_key, &state);
    for (i = 0; i < response_len; i++)
        printf("%c", response_plain[i]);
    fflush(stdout);
    shutdown(sock, 2);
    close(sock);
    return 1;
}
