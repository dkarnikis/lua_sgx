#ifndef _SGX_INC_
#define _SGX_INC_

#define LC_CTYPE 0
#define LC_NUMERIC 1
#define LC_TIME 2
#define LC_COLLATE 3
#define LC_MONETARY 4
#define LC_ALL 6
#define CLOCKS_PER_SEC 1000000
#define L_tmpnam 20
#define _IONBF 2
#define _IOLBF 1
#define _IOFBF 0


#ifndef _FILE_DEFINED

struct _IO_FILE {
  int _flags;		/* High-order word is _IO_MAGIC; rest is flags. */
#define _IO_file_flags _flags

  /* The following pointers correspond to the C++ streambuf protocol. */
  /* Note:  Tk uses the _IO_read_ptr and _IO_read_end fields directly. */
  char* _IO_read_ptr;	/* Current read pointer */
  char* _IO_read_end;	/* End of get area. */
  char* _IO_read_base;	/* Start of putback+get area. */
  char* _IO_write_base;	/* Start of put area. */
  char* _IO_write_ptr;	/* Current put pointer. */
  char* _IO_write_end;	/* End of put area. */
  char* _IO_buf_base;	/* Start of reserve area. */
  char* _IO_buf_end;	/* End of reserve area. */
  /* The following fields are used to support backing up and undo. */
  char *_IO_save_base; /* Pointer to start of non-current get area. */
  char *_IO_backup_base;  /* Pointer to first valid character of backup area */
  char *_IO_save_end; /* Pointer to end of non-current get area. */

  struct _IO_marker *_markers;

  struct _IO_FILE *_chain;

  int _fileno;
  int _flags2;
  long long int _old_offset; /* This used to be _offset but it's too small.  */

#define __HAVE_COLUMN /* temporary */
  /* 1+column number of pbase(); 0 is unknown. */
  unsigned short _cur_column;
  signed char _vtable_offset;
  char _shortbuf[1];

  /*  char* _save_gptr;  char* _save_egptr; */

};
typedef struct _IO_FILE FILE;
FILE *stdin, *stdout, *stderr;
#define _FILE_DEFINED
#endif

#ifndef _ERRNO_T_DEFINED
#define _ERRNO_T_DEFINED
typedef int errno_t;
#endif

#define _O_TEXT     0x4000  /* file mode is text (translated) */
#define _O_BINARY   0x8000  /* file mode is binary (untranslated) */

/* Seek method constants */
#define SEEK_CUR    1
#define SEEK_END    2
#define SEEK_SET    0

#define DECLARE_HANDLE(name) struct name##__{int unused;}; typedef struct name##__ *name
DECLARE_HANDLE  (HWND);

#ifndef CONST
#define CONST  const
#endif
typedef char CHAR;
typedef CONST CHAR *LPCSTR, *PCSTR;
typedef LPCSTR PCTSTR, LPCTSTR, PCUTSTR, LPCUTSTR;
typedef unsigned int UINT;


extern int single_enclave_instance;
extern int use_mempool;
extern int run_locally;
extern size_t total_alloced_bytes;
extern size_t total_freed_bytes;
struct tm1 {
    int    tm_sec; 
    int    tm_min; 
    int    tm_hour; 
    int    tm_mday; 
    int    tm_mon; 
    int    tm_year; 
    int    tm_wday; 
    int    tm_yday; 
    int    tm_isdst; 
};

struct lconv {
   char *decimal_point;
   char *thousands_sep;
   char *grouping;  
   char *int_curr_symbol;
   char *currency_symbol;
   char *mon_decimal_point;
   char *mon_thousands_sep;
   char *mon_grouping;
   char *positive_sign;
   char *negative_sign;
   char int_frac_digits;
   char frac_digits;
   char p_cs_precedes;
   char p_sep_by_space;
   char n_cs_precedes;
   char n_sep_by_space;
   char p_sign_posn;
   char n_sign_posn;
};



#endif
