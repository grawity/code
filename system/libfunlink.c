#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdio.h>
#include <string.h>

int unlink(const char *path) {
	static int (*real_unlink)(const char*);
	char *new;

	if (strncmp(path, "/tmp/", 5)) {
		if (!real_unlink)
			real_unlink = dlsym(RTLD_NEXT, "unlink");
		return real_unlink(path);
	} else if (asprintf(&new, "%s~", path) > 0)
		return rename(path, new);
	else
		return 0;
}
