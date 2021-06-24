#include "Enclave_t.h"
#include "sgx_defs.h"
#include <atomic>
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
#define AES_KEY_SIZE 16
/* the response of the server back to the client */
std::string server_response;
/* the keypair of the server */
unsigned char server_public_key[crypto_box_PUBLICKEYBYTES];
unsigned char server_secret_key[crypto_box_SECRETKEYBYTES];
int encrypted_mode = 0;                 /* are we using encryption                  */
int argc;                               /* number of lua arguments                  */
int count = 0;                          /* index for arguments                      */  
int use_mempool = 0;                 	/* use custom mempool                       */
char **argv;                            /* the actual arguments of lua              */
int single_enclave_instance = 0;        /* use a single Lua instance, faster code   */
int disable_execution_output = 0;       /* dont print the lua output on screen      */
struct client_info_t {
    int id;
    unsigned char client_public_key[crypto_box_PUBLICKEYBYTES];
    sgx_aes_ctr_128bit_key_t p_key[16];
	unsigned char *enc;
	short size = 0;
};
/* the current user id */
int current_user_id = 420;
/* holds all the entries for all the clients and their sockets */
std::vector<struct client_info_t *>client_info;

int run_locally = 0;                    /* do we run locally                        */
std::string code_to_execute = "";
std::vector<std::string> executable_code_vector;    /* the code is stored in a vector, and executed */ 
                                                    /* from it to enable global variables. JIT      */
std::string lvm = "./lua_vm";
/* used for indexing into the vector code lines */
int counter = -1;
int getc_len = 0;
char *getc_buffer = NULL;
size_t total_alloced_bytes = 0;
size_t total_freed_bytes = 0;
/* synchronization stuff */
volatile std::atomic<int> end_execution(0);                  /* clients request end of execution         */



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
 * get a client_info entry index by its id
 */
int 
get_client_by_pkey(unsigned char pkey[crypto_box_PUBLICKEYBYTES])
{
    int i;
    for (i = 0; i < (long)client_info.size(); i++) {
		if (memcmp(pkey, client_info.at(i)->client_public_key, crypto_box_PUBLICKEYBYTES) == 0) {
            return i;
		}
	}
	/* the client MUST EXIST */
    return -1;
}


/* 
 * get a client_info entry index by its id
 */
int 
get_client_by_id(int id)
{
    int i;
    for (i = 0; i < (long)client_info.size(); i++)
        if (client_info.at(i)->id == id) {
            return i;
		}
	/* the client MUST EXIST */
    abort();
}

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

void *
sgx_alloc(size_t len)
{
    void *ptr;
    ptr = NULL;
    if (use_mempool == 1) {
		/* alloc function */
    } else
		ptr = calloc(1, len);
    	if (ptr) {
			total_alloced_bytes += len;
    	}
    return ptr;
}

void
sgx_free(void *p)
{
    if (p) {
        if (use_mempool == 1) { 
            /* free func */
            return ;
    	} else {
        	free(p);
    	}
	}
}

void
randombytes(unsigned char *a,unsigned char b)
{
    sgx_read_rand(a, b);
}
/*
 * generate the public and private key of the server
 */
void
ecall_gen_pkeys(void)
{
    crypto_box_keypair(server_public_key, server_secret_key);
}


/*
 * return the public key of the server
 */
void
ecall_get_server_pkey(unsigned char *key, int k)
{
    memcpy(key, server_public_key, k);
}

/*
 * generate the aes key and send it to the client 
 */
void
ecall_send_aes_key(int id)
{
    Content c;
    int k;
    int index;
    unsigned char buffer[AES_KEY_SIZE];
    index = get_client_by_id(current_user_id);
	/* 
	 * A new client request is received, that has size == 0 -> 
	 * allocate new buffers
 	 */
	if (client_info.at(index)->size == 0) {
		/* generate the AES KEY */
		randombytes(buffer, AES_KEY_SIZE);
		/* copy the random key to our aes key */
		for (k = 0; k < AES_KEY_SIZE; k++)
			client_info.at(index)->p_key[0][k] = buffer[k];
    	/* encrypt the shared key and send it to the other party */
    	c = encrypt(buffer, (size_t)AES_KEY_SIZE, 
				client_info.at(index)->client_public_key, server_secret_key);
		/* allocate new buffer for our encrypted AES KEY */
		client_info.at(index)->enc = (unsigned char *)calloc(1, c.size);
		memcpy(client_info.at(index)->enc, c.bytes, c.size);
		client_info.at(index)->size = c.size;
	}
	/* fetch the encrypted AES KEY and send it to the client */
    ocall_send_packet(client_info.at(index)->enc, (int)client_info.at(index)->size, id);
}

/*
 * decrypt the incoming code from the client using AES
 */
char *
code_decrypt(char *str, int len, int cid)
{
    uint8_t iv[AES_KEY_SIZE];
    char *res;
    int index;
    sgx_status_t ret;
    index = get_client_by_id(current_user_id);
    ret = SGX_SUCCESS;
    res = (char *)sgx_alloc(len + 1);
    memset(iv, '5', 16);
    ret = sgx_aes_ctr_decrypt(client_info.at(index)->p_key, (uint8_t *)str, len, iv, 16, (uint8_t *)res);
    if (ret != SGX_SUCCESS)
        exit(EXIT_FAILURE);
    return res;
}

/*
 * Encrypt the data before sending them to the client
 */
void
ecall_encrypt(char *str, int len, int id)
{
    uint8_t iv[AES_KEY_SIZE];
    char *xd;
    sgx_status_t ret;
    xd = (char *)sgx_alloc(len);
    ret = SGX_SUCCESS;
    memset(iv, '5', 16);
    ret = sgx_aes_ctr_encrypt(client_info.at(get_client_by_id(current_user_id))->p_key, (uint8_t *)str, len, iv, 16, (uint8_t *)xd);
    if (ret != SGX_SUCCESS)
        exit(EXIT_FAILURE);
    ocall_send_packet((unsigned char *)xd, len, id);
    sgx_free(xd);
}

/*
 * init variables from the enclave and lua vm
 */
void
ecall_extra_args(size_t mode)
{
    encrypted_mode = mode;
}

/*
 * injects each line of client's code into the executable code buffer
 */
std::vector<std::string>
split_string(const std::string& str)
{
    std::vector<std::string> strings;
    std::string delimiter = "\n";
    std::string::size_type pos = 0;
    std::string::size_type prev = 0;
    while ((pos = str.find(delimiter, prev)) != std::string::npos) {
        strings.push_back(str.substr(prev, pos - prev));
        prev = pos + 1;
    }
    return strings;
}

/*
 * used on multiple clients mode, we need the cid of the client, in order
 * to decipher the code with the appropriate key
 */
void
ecall_add_code_encrypted(char *code, int buffer_size, int cid)
{
    int fsize;
    char *haha;
    /* plain code without encryption, insert it to the code queue */
    haha = read_code_data(code, &fsize, cid);
    std::string p(haha, fsize);
	free(haha);
    executable_code_vector = split_string(p);
}

/*
 * add plain code to execute in the execution buffer queue
 */
void
ecall_add_code(char *code, int buffer_size)
{
    /* plain code without encryption, insert it to the code queue */
    std::string p(code, buffer_size);
    code_to_execute = "dofile(\"" + p +"\")\n";
    executable_code_vector = split_string(code_to_execute);
}

/*
 * initialize enclave flags for lua vm
 */
void
ecall_init(int arg, int flm, int di, FILE *stdi, FILE *stdo, FILE *stde)
{
    stdin = stdi;
    stdout = stdo;
    stderr = stde;
    single_enclave_instance = flm;
    argc = arg;
    disable_execution_output = di;
    argv = (char **)sgx_alloc((argc + 2) * sizeof(char *));
	/* setup the name of the binary in the remote mode */
	argv[0] = (char *)lvm.c_str();
	count++;
	argc++;
}

/*
 * push argument to lua main
 */
void
ecall_push_arg(char *arg, unsigned long len)
{
    argv[count] = strdup(arg);
    argv[count][len] = '\0';
    count++;
}

/*
 * Read code data from file
 */
char *
read_code_data(char *fname, int *size, int id)
{
    /* read file contents */
    void *data;
    char *plain_data;
    FILE *code;
    size_t a;
    data = NULL;
    plain_data = NULL;
    code = fopen(fname, "r");                
    if (code == NULL)
        abort();
    /* get file size */
    ocall_get_file_size(size, code);
    /* alloc the data and encrypted buffer */ 
    data = (char *)sgx_alloc(*size);
    /* copy file contents to buffer */
    ocall_fread(&a, data, sizeof(char), *size, code);
    fclose(code);
    /* perform decrypt here if we have encrypted text */
    if (encrypted_mode == 1) {
        /* we are in encryption mode, decrypt the buffer */
        plain_data = code_decrypt((char *)data, *size, id);
        sgx_free(data);
        plain_data[*size] = '\0';
        return plain_data;
    } else
        return (char *)data;
}

/*
 * Start executing the code
 */
void
ecall_execute(int id)
{
    int server_response_len;
    char *response;
    char *first_data;                   /* code of client to be read from server */
	long unsigned int i;
    response = first_data = NULL;
    if (id == -1)
        run_locally = 1;
    /* trigger code execution */
    main(count, argv);
#ifdef DEBUG
    fprintf(stdout, "alloced bytes = %d\n", total_alloced_bytes);
#endif
    /* we are not running in server mode, end connection */
    if (id == -1)
    	return ;
    /* if the user has not requested any prints, we send empty character back */
    if (strlen(server_response.c_str()) == 0)
        server_response = " ";
    server_response_len = server_response.length();
    response = (char *)sgx_alloc(sizeof(char) * server_response_len + 1);
    strncpy(response, server_response.c_str(), server_response_len + 1);
    if (encrypted_mode == 1) {
    	ecall_encrypt(response, server_response_len, id);
    } else
    	ocall_send_packet((unsigned char *)response, server_response_len, id);
	/* cleanup time */
    sgx_free(response);
#if 1
	if (single_enclave_instance == 0) {
		for (i = 0; i < client_info.size(); i++)
			sgx_free(client_info.at(i));
		client_info.clear();
	}
#endif
	server_response = "";
	code_to_execute = "";
	executable_code_vector.clear();
	counter = -1;
	getc_buffer = NULL;
	/* free the vector except the name of the luavm which is the first arg */
	for (i = 1; i < (unsigned long int)argc; i++) {
#ifdef DEBUG
		fprintf(stdout, "Freeing %s\n", argv[i]);
#endif
		sgx_free(argv[i]);
	}
	/* reset the args */
	count = 1;
}

int
fprintf(FILE *file, const char* fmt, ...)
{
    #define BUFSIZE 1000
    int res;
    char buf[BUFSIZE] = {'\0'};
    va_list ap;
    res = 0;
    va_start(ap, fmt);
    vsnprintf(buf, BUFSIZE, fmt, ap);
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
    /* print output enabled */
    if (disable_execution_output == 0 || (disable_execution_output == 1 && fd != stdout))
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

size_t
fread(void *ptr, size_t size, size_t nmemb, FILE *stream)
{
    size_t a;
    char *xd;
    memset(ptr, 0, size * nmemb);
    /* 
     * lua parses the first char on the file for some weird reason
     * and the the rest
     */
    ocall_fread(&a, ptr, size, nmemb, stream);
    if (encrypted_mode == 1) {
        /* if we did not read anything, skip */
        if (a == 0) 
            return a;	
    	xd = NULL;
        /* we are in encryption mode, decrypt the buffer */
        xd = code_decrypt((char *)ptr, a, current_user_id);
        /* copy the buffer into lua code buffer(ptr) */
        memcpy(ptr, xd, a);
        sgx_free(xd);
    }
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
    if (strcmp(rec_filename(stream), rec_filename(stdin)) == 0 && encrypted_mode == 1) {
        /* init phase */
        if (counter == -1) {
            /* reset the buffer if it is not in the correct place */
            fseek(stream, 0, SEEK_SET);
            fseek(stream, 0, SEEK_END);
            getc_len = ftell(stream);
            fseek(stream, 0, SEEK_SET);
            /* got the file len */
            getc_buffer = (char *)sgx_alloc(getc_len);
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
    str = (char *)sgx_alloc(len);
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
    int index;
    index = get_client_by_pkey(client_key);
	if (index == -1) {
		current_user_id++;
	    struct client_info_t *ci;
    	ci = (struct client_info_t *)calloc(1, sizeof(struct client_info_t));
    	ci->id = current_user_id;
		memcpy(ci->client_public_key, client_key, k);
    	client_info.push_back(ci);
	} else {
		//client_info.at(index)->id = client_id;
		/* we found our pkey, update tis entries */
		memcpy(client_info.at(index)->client_public_key, client_key, k);
	}
}


