#include "Enclave_t.h"
#include "dh/tweetnacl.h"
#include "sgx_defs.h"
#include "sgx_trts.h"
#include "lua.h"
#include "sgx_tcrypto.h"
#include <stdio.h>   
#include <string.h>  
#include <stdlib.h>  
#include <vector>
#include <string>
#include <assert.h>
#include <unistd.h>  
#include "sgx_structs.h"
#include <sgx_thread.h>
#include <time.h>
/* size of the aes encryption key in bytes */
#define KEY_SIZE 16
#define CHUNK_LEN 4096

/* the response of the server back to the client */
std::string server_response;
/* the keypair of the server */
unsigned char server_public_key[crypto_box_PUBLICKEYBYTES];
unsigned char server_private_key[crypto_box_SECRETKEYBYTES];
int disable_execution_output = 0;       /* dont print the lua output on screen      */
unsigned char client_public_key[crypto_box_PUBLICKEYBYTES];
unsigned char encryption_key[KEY_SIZE * 2];


unsigned char *enc;
/*
 * 1 = read everything without decrypting. Is used for local execution or
 * for bootstraping the lua instance for local/remote
 */
int enclave_bootstrap = 1;

int run_locally = 0;                    /* do we run locally                        */
/* used for indexing into the vector code lines */
int counter = -1;
int getc_len = 0;
char *getc_buffer = NULL;

void bootstrap_lua();

unsigned char *decrypt_chunks(unsigned char *enc, size_t data_size);


void
print_key(const char *s, uint8_t *key, int size)
{
    int i;
    printf("%s: ", s);
    for (i = 0; i < size; i++)
        printf("%u", key[i]);
    printf("\n");
}

unsigned char * code_decrypt(unsigned char *str, size_t len);

int
printf(const char* fmt, ...)
{
    #define BS 100
    int res;
    char buf[BS] = {'\0'};
    size_t bob;
    va_list ap;
    res = 0;
    va_start(ap, fmt);
    vsnprintf(buf, BS, fmt, ap);
    va_end(ap);
    res += ocall_fwrite(&bob, buf, 1, strlen(buf), stdout);
    return res;   
}


/*
 * generate the public and private key of the server
 */
void
ecall_gen_pkeys(void)
{
    crypto_box_keypair(server_public_key, server_private_key);
}


/*
 * return the public key of the server
 */
void
ecall_get_server_pkey(unsigned char *key, int k)
{
    memcpy(key, server_public_key, k);
}


void
randombytes(unsigned char *b, unsigned char len)
{
    sgx_read_rand(b, len);
}

void
gen_encryption_key(unsigned char *b, size_t len)
{
    //unsigned char buffer[KEY_SIZE];
    sgx_read_rand(b, len);
}



/*
 * generate the aes key and send it to the client 
 */
void
ecall_send_aes_key(int id)
{
    Content c;
    gen_encryption_key(encryption_key, KEY_SIZE * 2);
    c = encrypt(encryption_key, KEY_SIZE, client_public_key, server_private_key);
    ocall_send_packet(id, c.bytes, c.size);
    free(c.bytes);
    c = encrypt(&encryption_key[16], KEY_SIZE, client_public_key, server_private_key);
    ocall_send_packet(id, c.bytes, c.size);
    free(c.bytes);
}

/*
 * initialize enclave flags for lua vm
 */
void
ecall_init(int di, FILE *stdi, FILE *stdo, FILE *stde)
{
    stdin = stdi;
    stdout = stdo;
    stderr = stde;
    disable_execution_output = di;
    bootstrap_lua();
}

/*
 * Start executing the code
 */
void
ecall_execute(int id, int local_exec)
{
    char *response;
    if (local_exec == 1) 
        bootstrap_lua();
    // if local_exec = 0, use encryption, else all plain text
    enclave_bootstrap = local_exec;
    response = NULL;
    char **argv;                            /* the actual arguments of lua              */
    argv = (char **)calloc(4, sizeof(char *));
    argv[0] = strdup("code.lua");
    argv[1] = argv[0]; 
    argv[2] = NULL;
    // trigger code execution
    main(3, argv);
    /* if the user has not requested any prints, we send empty character back */
    if (strlen(server_response.c_str()) == 0)
        server_response = " ";
    response = (char *)calloc(1, sizeof(char) * server_response.length() + 1);
    strncpy(response, server_response.c_str(), server_response.length() + 1);
    if (local_exec == 0) {
        unsigned char *xd = decrypt_chunks((unsigned char *)response, server_response.length());
        ocall_send_packet(id, (unsigned char *)xd, server_response.length());
        free(xd);
    } else 
        ocall_send_packet(id, (unsigned char *)response, server_response.length() + 1);
	// cleanup time
    free(response);
	server_response = "";
    free(argv[0]);
    free(argv);
	counter = -1;
	getc_buffer = NULL;
}

int
fprintf(FILE *file, const char* fmt, ...)
{
    //#define BUFSIZE 1000
    int res;
    char buf[BUFSIZ] = {'\0'};
    va_list ap;
    res = 0;
    va_start(ap, fmt);
    vsnprintf(buf, BUFSIZ, fmt, ap);
    va_end(ap);
    res+= fwrite(buf, 1, strlen(buf), file);
    return res;   
}

char *
fgets(char *str, int n, FILE *fd)
{
    char *result;
    /* clear the buffer of the str */
    memset(str, 0, n);
    ocall_fgets(&result, str, n, fd);
    return result;
}

char *
getenv(const char *name)
{
    char *res;
    ocall_getenv(&res, name);
    return res;
}

size_t
fwrite(const void *buffer, size_t size, size_t cont, FILE *fd)
{
    size_t res;
    res = cont * size;
    if (fd == stdout)
        server_response.append((char *)buffer);
    // print output enabled
    // on remote opts, dont print anything
    if (enclave_bootstrap == 1)
        ocall_fwrite(&res, buffer, size, cont, fd);
    return res;
}

struct lconv *
localeconv(void)
{
    lconv *res;
    ocall_localeconv(&res);
    return res;
}

int
fputs(const char *str, FILE *stream)
{
    int res;
    res = 0;
    /* print the prompt only on local execution */
    ocall_fputs(&res, str, stream); 
    return res;
}

FILE *
fopen(const char *filename, const char *mode)
{
    FILE *fp;
    ocall_fopen(&fp, filename, mode);
    return fp;
}

void
exit(int status_)
{

    printf("Error! x\n");
    abort();
    ocall_exit(status_);
}

char *
setlocale(int category, const char *locale)
{
    char *a;
    ocall_setlocale(&a, category, locale);
    return a;
}

int
system(const char *str)
{
    int a;
    return ocall_system(&a, str);
}

int 
remove(const char *filename)
{
    int a;
    ocall_remove(&a, filename);
    return a;
}

int
rename(const char *old_filename, const char *new_filename)
{
    int a;
    a = 0;
    ocall_rename(&a, old_filename, new_filename);
    return a;
}

char *
tmpnam(char *str)
{
    char *a;
    a = NULL;
    ocall_tmpnam(&a, str);
    return a;
}

/*
 * Don't close the file now to save time 
 */
int
fclose(FILE *ptr)
{
    int a;
    ocall_fclose(&a, ptr);
    return a;
}

int
setvbuf(FILE *stream, char *buffer, int mode, size_t size)
{
    int a;
    a = 0;
    ocall_setvbuf(&a, stream, buffer, mode, size);
    return a;
}

long int
ftell(FILE *stream)
{
    long int a;
    a = 0;
    ocall_ftell(&a, stream);
    return a;
}

int
fseek(FILE *stream, long int offset, int whence)
{
    int a;
    a = 0;
    ocall_fseek(&a, stream, offset, whence);
    return a;
}

FILE *
tmpfile(void)
{
    FILE *fd;
    fd = NULL;
    ocall_tmpfile(&fd);
    return fd;
}

void
clearerr(FILE *stream)
{
    ocall_clearerr(stream);
}


/*
 * decrypt the incoming code from the client using AES
 */
unsigned char *
code_decrypt(unsigned char *str, size_t len)
{
    unsigned char n[crypto_stream_NONCEBYTES];
    unsigned char *cipher;
    cipher = (unsigned char *)calloc(len, sizeof(unsigned char)+ 1);
    memset(n, 0, crypto_stream_NONCEBYTES);
    crypto_stream_xor(cipher, str, len, n, encryption_key);
    cipher[len] = '\0';
    return cipher;
}

/*
 * Same function for encryption/decryption
 */
unsigned char *
decrypt_chunks(unsigned char *enc, size_t data_size)
{
    size_t len, rx_bytes;
    unsigned char *plain_text, *cipher;
    len = CHUNK_LEN;
    rx_bytes = 0;
    plain_text = (unsigned char *)calloc(1, data_size + 1);
    while (rx_bytes != data_size) {
        if ((rx_bytes + len) > data_size) {
            len = data_size - rx_bytes;
        }
        cipher =  code_decrypt(&enc[rx_bytes], len);
        memcpy(&plain_text[rx_bytes], cipher, len);
        rx_bytes += len;
        free(cipher);
    }
    return plain_text;
}


size_t
fread(void *ptr, size_t size, size_t nmemb, FILE *stream)
{
    size_t a;
    unsigned char *plain_data;
    memset(ptr, 0, size * nmemb);
    /* 
     * lua parses the first char on the file for some weird reason
     * and the the rest
     */
    ocall_fread(&a, ptr, size, nmemb, stream);
    // if we did not read anything, skip or if we are running locally
    if (a == 0 || enclave_bootstrap == 1) 
        return a;
    // we are in encryption mode, decrypt the buffer
    plain_data = decrypt_chunks((unsigned char *)ptr, a);
#if 1
    if (a == 1)
        printf("%s\n", plain_data);
#endif
    // copy the buffer into lua code buffer(ptr)
    memcpy(ptr, plain_data, a);
    free(plain_data);
    return a;
}

int
ferror(FILE *stream)
{
    int a;
    a = 0;
    ocall_ferror(&a, stream);
    return a;
}

int
getc(FILE *stream)
{
    int a;
    a = 0;
    /* 
     * Special handling from programs that have user inputs and are encrypted 
     * Lua vm handles input from getc, char by char. In our cases where our input
     * text is encrypted, fetching chars from encypted buffer will result into garbage.
     * The solution to this is to parse the whole file into a buffer, decrypt it once
     * and each time a getc is executed, we return the next char from the buffer
     * ignoring the actual use of getc
     */
    if (strcmp(rec_filename(stream), rec_filename(stdin)) == 0) {
        /* init phase */
        if (counter == -1) {
            /* reset the buffer if it is not in the correct place */
            fseek(stream, 0, SEEK_SET);
            fseek(stream, 0, SEEK_END);
            getc_len = ftell(stream);
            fseek(stream, 0, SEEK_SET);
            /* got the file len */
            getc_buffer = (char *)calloc(1, getc_len);
            /* decrypt the buffer */
            getc_len = fread(getc_buffer, 1, getc_len, stream);
            /* start fetching characters */
            counter = 0;
            return getc_buffer[0];
        } else {
            /* get next characters */
            counter++;
            if (counter >= getc_len) {
                counter = 0;
                return EOF;
            } else
                /* return the new characters */
                return getc_buffer[counter];
        }
    }
    ocall_getc(&a, stream);
    return a;
}

int
ungetc(int ch, FILE *stream)
{
    int a;
    a = 0;
    ocall_ungetc(&a, ch, stream);
    return a;
}

FILE *
freopen(const char *filename, const char *mode, FILE *stream)
{
    FILE *fd;
    fd = NULL;
    ocall_freopen(&fd, filename, mode, stream);
    return fd;
}

int
feof(FILE *stream)
{
    int a;
    a = 0;
    ocall_feof(&a, stream);
    return a;
}

int
rand(void)
{
    int a;
    //ocall_rand(&a);
	sgx_read_rand((unsigned char *)&a, sizeof(int));
	if (a < 0)
		a*=-1;
    return a;   
}

void
srand(unsigned int seed)
{   
    ocall_srand(seed);
}

int
fflush(FILE *ptr)
{
    int res;
    res = 0;
    return ocall_fflush(&res, ptr);
}

long int
labs (long int i)
{
    return i < 0 ? -i : i;
}

char *
rec_filename(FILE *f)
{
    char *rf;
    rf = NULL;
    recover_filename(&rf, f);
    return rf;
}

void
perror(const char *s)
{   
    fprintf(stdout, "%s", s);
    fflush(stdout);
    abort();
}

long int
clock()
{
    long int a;
    a = 0;
    ocall_clock(&a);
    return a;
}

long int
mktime(struct tm *timeptr)
{
    long int a;
    a = 0;
    ocall_mktime(&a, timeptr);
    return a;
}

struct tm *
localtime(const long int *timer)
{
    struct tm *a;
    a = NULL;
    ocall_localtime(&a, timer);
    return a;
}

struct tm *
gmtime(const long int *timer)
{
    struct tm *a;
    a = NULL;
    ocall_gmtime(&a, timer);
    return a;
}

long int
time(long int *src)
{
    long int a;
    a = 0;
    ocall_time(&a, src);
    return a;
}

char *
strcpy(char* destination, const char* source)
{
    if (destination == NULL)
    	return NULL;
    char *ptr;
    ptr = destination;
    while (*source != '\0') {
        *destination = *source;
        destination++;
        source++;
    }
    *destination = '\0';
    return ptr;
}


char *
strdup(char *src)
{
    char *str;
    size_t len;
	len = strlen(src) + 1;
    str = (char *)calloc(1, len);
    if (str)
        memcpy(str, src, len);
    str[len-1] = '\0';
    return str;
}

FILE *
popen(const char *command, const char *type)
{
    FILE *a;
    ocall_popen(&a, command, type);
    return a;
}

int
pclose(FILE *stream)
{
    int a;
    ocall_pclose(&a, stream);
    return a;
}

/*
 * Register the client public key
 */
void
ecall_register_client(int client_id, unsigned char *client_key, int k)
{
	memcpy(client_public_key, client_key, k);
}
