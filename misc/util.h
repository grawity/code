#include <string.h>

static inline int streq(const char *a, const char *b) {
	return strcmp(a, b) == 0;
}
