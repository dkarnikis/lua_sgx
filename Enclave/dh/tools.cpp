#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

// http://stackoverflow.com/a/1921557
#include "../Enclave_t.h"
#include "../sgx_defs.h"
#include "../sgx_structs.h"
#include "../sgx_trts.h"
#include "../sgx_funcs.h"

void error(int code, const char message[]) {
    fprintf(stderr, "Error: ");
    fputs(message, stderr);
    fprintf(stderr, "\n");
    exit(code);
}

void errorf(int code, const char message[], char arg[]) {
    fprintf(stderr, "Error: ");
    fprintf(stderr, message, arg);
    fprintf(stderr, "\n");
    exit(code);
}

char * bytes_to_hex(unsigned char bytes[], int size) {
    char *hex = (char *)calloc(1, (size * 2) + 1);
    if (hex == NULL) error(1, "Malloc failed!");
    for (int i = 0; i < size; i++) {
        sprintf(hex + (i * 2), "%02x", bytes[i]);
    }
    return hex;
}

#if 0
FILE * create_file(char filename[]) {
    // http://stackoverflow.com/a/230581
    int fd = open(filename, O_CREAT | O_WRONLY | O_EXCL, S_IRUSR | S_IWUSR);
    if (fd < 0) errorf(1, "Could not write to %s", filename);
    // http://stackoverflow.com/a/1941472
    return fdopen(fd, "wb");
}

bool file_exists(char arg[]) {
    // http://stackoverflow.com/a/230068
    // Not perfect, because e.g. it won't allow the use of /dev/stdout
    if (access(arg, F_OK) != -1) return true;
    return false;
}

void read_key(char filename[], unsigned char key[], int key_size) {
    FILE *f = fopen(filename, "rb");
    if (fread(key, 1, key_size, f) != key_size)
        errorf(1, "Could not read the key from <%s>", filename);
    fclose(f);
}

#endif

Content read_file(char filename[]) {
    FILE *f = fopen(filename, "rb");
    Content c;
    if (f == 0) errorf(1, "Could not read <%s>", filename);
    fseek(f, 0, SEEK_END);
    long size = ftell(f);
    if (size < 0) errorf(1, "Could not read <%s>", filename);
    c.size = (size_t)size;
    fseek(f, 0, SEEK_SET);
    c.bytes = (unsigned char *)calloc(1, c.size);
    if (c.bytes == NULL) error(1, "Malloc failed!");
    fread(c.bytes, c.size, 1, f);
    fclose(f);
    return c;
}
