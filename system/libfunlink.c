#define _GNU_SOURCE
#include <dlfcn.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

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

int unlinkat(int dirfd, const char *pathname, int flags) {
	static int (*real_unlinkat)(int, const char*, int);
	struct stat tmpst, pathst;
	char *newname;

	if (stat("/tmp", &tmpst) < 0)
		goto real;

	if (fstatat(dirfd, pathname, &pathst, AT_SYMLINK_NOFOLLOW) < 0)
		goto real;

	if (tmpst.st_dev != pathst.st_dev)
		goto real;

	if (asprintf(&newname, "%s~", pathname) <= 0)
		goto real;

	if (renameat(dirfd, pathname, dirfd, newname) < 0)
		goto real;

	return 0;

real:
	if (!real_unlinkat)
		real_unlinkat = dlsym(RTLD_NEXT, "unlinkat");

	return real_unlinkat(dirfd, pathname, flags);
}
