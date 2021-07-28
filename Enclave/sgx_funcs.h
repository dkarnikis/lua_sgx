#ifndef SGX_FUNCS_H
#define SGX_FUNCS_H
#include "dh/tools.h"
#include "dh/tweetnacl.h"
#include "sgx_structs.h"
char *fgets(char *str, int n, FILE *fd);
size_t fwrite(const void *buffer, size_t size, size_t cont, FILE *fd);
int fflush(FILE *ptr);
char *getenv(const char *name);
int fputs(const char *str, FILE *stream);
int fprintf(FILE *file, const char *fmt, ...);
char *getenv(const char *name);
long int clock();
long int time(long int *src);
char *strcpy(char *strDest, const char *strSrc);
lconv *localeconv(void);
FILE *fopen(const char *filename, const char *mode);
void exit(int status);
char *setlocale(int category, const char *locale);
int system(const char *str);
int remove(const char* filename);
long int mktime(struct tm *timeptr);
struct tm *localtime(const long int *timer);
struct tm *gmtime(const long int *timer);
int rename(const char *old_filename, const char *new_filename);
char *tmpnam(char *str);
int fclose(FILE *fd);
int setvbuf(FILE *stream, char *buffer, int mode, size_t size);
long int ftell(FILE *stream);
int fseek(FILE *stream, long int offset, int whence);
FILE *tmpfile(void);
void clearerr(FILE *stream);
size_t fread(void *ptr, size_t size, size_t nmemb, FILE *stream);
int ferror(FILE *stream);
int getc(FILE *stream);
int ungetc(int ch, FILE *stream);
FILE *freopen(const char *filename, const char *mode, FILE *stream);
int feof(FILE *stream);
int rand(void);
void srand(unsigned int seed);
int sprintf(char *str, const char *string,...); 
int fscanf(FILE *stream, const char *format, ...);
int printf(const char *format, ...);
int putchar(int a);
char *strcat(char *dst, const char *src);
int fscanf(FILE *stream, const char *format, double *d);
void print_num(size_t s);
void perror(const char *s);
char *strdup(char *src);
FILE *popen(const char *a, const char *b);
void randombytes(unsigned char *a, unsigned char b);
int pclose(FILE *f);
char *read_code_data(char *fname, int *size, int id);
/* the function to perform the dh encryption */
Content encrypt(unsigned char *a, size_t len, unsigned char *b, unsigned char *c);
char *rec_filename(FILE *f);
int main(int argc, char **argv);
extern int enclave_bootstrap;
#endif
