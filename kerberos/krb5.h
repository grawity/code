#include <krb5/krb5.h>

#ifdef KRB5_KRB5_H_INCLUDED
#	define KRB5_MIT
#elif defined(__KRB5_H__)
#	define KRB5_HEIMDAL
#endif

#ifdef KRB5_HEIMDAL
#	include <krb5/com_err.h>
#endif
