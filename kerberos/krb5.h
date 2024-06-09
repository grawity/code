#if defined(HAVE_KRB5_H)
#  include <krb5.h>
#elif defined(HAVE_FREEBSD)
#  include <krb5.h>
#  include <com_err.h>
#elif defined(HAVE_NETBSD)
#  include <krb5/krb5.h>
#  include <krb5/com_err.h>
#elif defined(HAVE_OPENBSD)
#  include <kerberosV/krb5.h>
#  include <kerberosV/com_err.h>
#elif defined(HAVE_SOLARIS)
#  include <kerberosv5/krb5.h>
#  include <kerberosv5/com_err.h>
#else
#  include <krb5.h>
#endif

#if defined(KRB5_KRB5_H_INCLUDED)
#  define KRB5_MIT
#  define HAVE_KRB5_COLLECTIONS
#  define HAVE_KRB5_CONFIG_PRINCIPALS
#elif defined(_KRB5_H)
#  define KRB5_MIT
#  define KRB5_MIT_SOLARIS
#elif defined(__KRB5_H__)
#  define KRB5_HEIMDAL
#endif

#include "config-krb5.h"
