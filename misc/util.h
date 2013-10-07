#include <string.h>
#include <strings.h>
#include <sys/types.h>
#include <stdlib.h>

int mkdir_p(const char *, mode_t);

char * shell_escape(const char *);

static inline int streq(const char *a, const char *b) {
	return strcmp(a, b) == 0;
}

static inline const char *startswith(const char *s, const char *prefix)
{
	size_t sz = prefix ? strlen(prefix) : 0;

        if (s && sz && strncmp(s, prefix, sz) == 0)
                return s + sz;
	return NULL;
}

static inline const char *startswith_no_case(const char *s, const char *prefix)
{
	size_t sz = prefix ? strlen(prefix) : 0;

        if (s && sz && strncasecmp(s, prefix, sz) == 0)
                return s + sz;
	return NULL;
}

static inline const char *endswith(const char *s, const char *postfix)
{
	size_t sl = s ? strlen(s) : 0;
	size_t pl = postfix ? strlen(postfix) : 0;

	if (pl == 0)
		return (char *)s + sl;
	if (sl < pl)
		return NULL;
	if (memcmp(s + sl - pl, postfix, pl) != 0)
		return NULL;
	return (char *)s + sl - pl;
}

static inline void freep(void *p) {
	free(*(void**)p);
}

#define _cleanup_(f)	__attribute__((cleanup(f)))
#define _cleanup_free_	_cleanup_(freep)

#if defined(__GNUC__) && !defined(strdupa)
/* Copied from glibc string/string.h */
/* Duplicate S, returning an identical alloca'd string.  */
# define strdupa(s)							      \
  (__extension__							      \
    ({									      \
      const char *__old = (s);						      \
      size_t __len = strlen (__old) + 1;				      \
      char *__new = (char *) __builtin_alloca (__len);			      \
      (char *) memcpy (__new, __old, __len);				      \
    }))

/* Return an alloca'd copy of at most N bytes of string.  */
# define strndupa(s, n)							      \
  (__extension__							      \
    ({									      \
      const char *__old = (s);						      \
      size_t __len = strnlen (__old, (n));				      \
      char *__new = (char *) __builtin_alloca (__len + 1);		      \
      __new[__len] = '\0';						      \
      (char *) memcpy (__new, __old, __len);				      \
    }))
#endif
