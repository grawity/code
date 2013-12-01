#define HAVE_FLOCK
#define HAVE_LASTLOG
#define HAVE_UTMP

#ifdef __FreeBSD__
#  undef  HAVE_LASTLOG
#  undef  HAVE_UTMP
#  define HAVE_UTMPX
#endif

#ifdef __linux__
#  define HAVE_ACCT
#  ifndef ACCT_FILE
#    define ACCT_FILE "/var/log/account/pacct"
#  endif
#endif

#ifdef HAVE_SOLARIS
#  undef  HAVE_FLOCK
#endif
