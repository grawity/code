#define HAVE_FLOCK
#define HAVE_LASTLOG
#define HAVE_UTMP

#ifdef __FreeBSD__
#undef  HAVE_LASTLOG
#undef  HAVE_UTMP
#define HAVE_UTMPX
#define NO_ACCT
#endif

/* TODO: use a builtin define */
#ifdef HAVE_SOLARIS
#undef  HAVE_FLOCK
#endif
