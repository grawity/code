#include <string.h>
#include <sys/types.h>

int mkdir_p(const char *, mode_t);

static inline int streq(const char *a, const char *b) {
	return strcmp(a, b) == 0;
}
