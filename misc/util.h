#include <string.h>
#include <sys/types.h>
#include <stdlib.h>

int mkdir_p(const char *, mode_t);

static inline int streq(const char *a, const char *b) {
	return strcmp(a, b) == 0;
}

static inline void freep(void *p) {
	free(*(void**)p);
}

#define _cleanup_(f)	__attribute__((cleanup(f)))
#define _cleanup_free_	_cleanup_(freep)
