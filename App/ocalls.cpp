/*
 * SGX ocall function implementation
 */
#include "sgx_urts.h"
#include "sgx_defs.h"
#include "Enclave_u.h"
#include <time.h>
#include <unistd.h>
#include <stdio.h>   
#include <thread>       
#include <locale.h>
#include <vector>

int
ocall_get_file_size(FILE *file)
{
#ifdef DEBUG1
	printf("%s\n", __FUNCTION__);
#endif
    int size;
    fseek(file, 0L, SEEK_END);
    size = (int)ftell(file);
    fseek(file, 0L, SEEK_SET);
    return size;
}

char *
ocall_setlocale(int category, const char *locale)
{
#ifdef DEBUG1
	printf("%s\n", __FUNCTION__);
#endif
    return setlocale(category, locale);
}

void
ocall_exit(int status)
{
#ifdef DEBUG1
	printf("%s\n", __FUNCTION__);
#endif
    exit(status);
}

long int
ocall_clock()
{
#ifdef DEBUG1
	printf("%s\n", __FUNCTION__);
#endif
    return clock();
}

long int
ocall_time(long int *src)
{
#ifdef DEBUG1
	printf("%s\n", __FUNCTION__);
#endif
    return time(src);
}

char *
ocall_getenv(const char *name)
{
#ifdef DEBUG1
	printf("%s\n", __FUNCTION__);
#endif
    return getenv(name);
}

int
ocall_write(int file, const void *buf, unsigned int size)
{
#ifdef DEBUG1
	printf("%s\n", __FUNCTION__);
#endif
   	return (int)write(file, buf, size);
}

int
ocall_fputs(const char *str, FILE *fd)
{
#ifdef DEBUG1
	printf("%s\n", __FUNCTION__);
#endif
    return fputs(str, fd);
}

size_t
ocall_fwrite(const void *buffer, size_t size, size_t count, FILE *fd)
{
#ifdef DEBUG1
	printf("%s\n", __FUNCTION__);
#endif
    return fwrite(buffer, size, count, fd);
}


char *
ocall_fgets(char *str, int n, FILE *fd)
{
#ifdef DEBUG1
	printf("%s\n", __FUNCTION__);
#endif
    char *f;
    f = fgets(str, n, fd);
    return f;
}

int
ocall_fflush(FILE *ptr)
{
#ifdef DEBUG1
	printf("%s\n", __FUNCTION__);
#endif
    return fflush(ptr);
}

struct lconv *
ocall_localeconv()
{
#ifdef DEBUG1
    printf("%s\n", __FUNCTION__);
#endif
    return localeconv();
}

FILE *
ocall_fopen(const char *filename, const char *mode)
{
#ifdef DEBUG1
    printf("%s\n", __FUNCTION__);
#endif
    FILE *fp;
    fp = fopen(filename, mode); 
    return fp;
}	

int
ocall_system(const char *str)
{
#ifdef DEBUG1
    printf("%s\n", __FUNCTION__);
#endif
    return system(str);
}

long int
ocall_mktime(struct tm *timeptr)
{
#ifdef DEBUG1
    printf("%s\n", __FUNCTION__);
#endif
    return (long int)mktime((struct tm *)timeptr);
}

int
ocall_remove(const char *filename)
{
#ifdef DEBUG1
    printf("%s\n", __FUNCTION__);
#endif
    return remove(filename);
}

struct tm *
ocall_localtime(const long int *timer)
{
    return (struct tm *)localtime(timer);
}

struct tm *
ocall_gmtime(const long int *timer)
{
    (void)(timer);
    return (struct tm *)gmtime(timer);
}

int
ocall_rename(const char *old_filename, const char *new_filename)
{
#ifdef DEBUG1
    printf("%s\n", __FUNCTION__);
#endif
    return rename(old_filename, new_filename);
}

char *
ocall_tmpnam(char *str)
{
#ifdef DEBUG1
    printf("%s\n", __FUNCTION__);
#endif
    return tmpnam(str);
}

int
ocall_fclose(FILE *ptr)
{
	int a;
    a = fclose(ptr);
	return a;
}

int
ocall_setvbuf(FILE *stream, char *buffer, int mode, size_t size)
{
#ifdef DEBUG1
    printf("%s\n", __FUNCTION__);
#endif
    return setvbuf(stream, buffer, mode, size);
}

long int
ocall_ftell(FILE *stream)
{
#ifdef DEBUG1
    printf("%s\n", __FUNCTION__);
#endif
    return ftell(stream);
}

int
ocall_fseek(FILE *stream, long int offset, int whence)
{
#ifdef DEBUG1
    printf("%s\n", __FUNCTION__);
#endif
    return fseek(stream, offset, whence);
}

FILE *
ocall_tmpfile()
{
#ifdef DEBUG1
    printf("%s\n", __FUNCTION__);
#endif
    return tmpfile();
}

void
ocall_clearerr(FILE *stream)
{
#ifdef DEBUG1
    printf("%s\n", __FUNCTION__);
#endif
    clearerr(stream);
}

char *
recover_filename(FILE *f)
{
#ifdef DEBUG1
    printf("%s\n", __FUNCTION__);
#endif
    int fd;
    ssize_t n;
    char fd_path[255];
    char *filename;
    filename = (char *)calloc(1, 255);
    fd = fileno(f);
    sprintf(fd_path, "/proc/self/fd/%d", fd);
    n = readlink(fd_path, filename, 255);
    if (n < 0)
        return NULL;
    filename[n] = '\0';
    return filename;
}

size_t
ocall_fread(void *ptr, size_t size, size_t nmemb, FILE *stream)
{
#ifdef DEBUG1
    printf("%s\n", __FUNCTION__);
#endif
    return fread(ptr, size, nmemb, stream);
}

int
ocall_ferror(FILE *stream)
{
#ifdef DEBUG1
    printf("%s\n", __FUNCTION__);
#endif
    return ferror(stream);
}

int
ocall_getc(FILE *stream)
{
#ifdef DEBUG1
    printf("%s\n", __FUNCTION__);
#endif
    return getc(stream);
}

int
ocall_ungetc(int ch, FILE *stream)
{
#ifdef DEBUG1
    printf("%s\n", __FUNCTION__);
#endif
    return ungetc(ch, stream);
}

FILE *
ocall_freopen(const char *filename, const char *mode, FILE *stream)
{
#ifdef DEBUG1
    printf("%s\n", __FUNCTION__);
#endif
    return freopen(filename, mode, stream);
}

int
ocall_feof(FILE *stream)
{
#ifdef DEBUG1
    printf("%s\n", __FUNCTION__);
#endif
    return feof(stream);
}

int
ocall_rand()
{   
#ifdef DEBUG1
    printf("%s\n", __FUNCTION__);
#endif
    return rand();
}

/* 
 * random ocall function
 */
void
ocall_srand(unsigned int seed)
{

#ifdef DEBUG1
    printf("%s\n", __FUNCTION__);
#endif
    srand(seed);
}

FILE *
ocall_popen(const char *c, const char *t)
{
    return popen(c, t);
}

int 
ocall_pclose(FILE *stream)
{
    return pclose(stream);
}

