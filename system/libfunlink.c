#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int unlink(const char *path) {
	static int (*real_unlink)(const char*);
	const char *real;
	char *new;

	real = realpath(path, NULL);
	if (!real)
		real = path;

	if (strncmp(real, "/tmp/", 5)) {
		if (!real_unlink)
			real_unlink = dlsym(RTLD_NEXT, "unlink");
		return real_unlink(path);
	} else if (asprintf(&new, "%s~", path) > 0)
		return rename(path, new);
	else
		return 0;
}
