/* Preload library to magically resolve symlinks (to be used for sftp-server
 * when dealing with symlink-incapable clients) */

#define _GNU_SOURCE
#include <dlfcn.h>
#include <sys/stat.h>
#include <fcntl.h> /* AT_* */

#if 0
int lstat(const char *pathname, struct stat *statbuf) {
	static int (*real_lstat)(const char *, struct stat *);
	int result = -1;

	if (!real_lstat)
		real_lstat = dlsym(RTLD_NEXT, "lstat");

	result = stat(pathname, statbuf);

	if (result < 0)
		result = real_lstat(pathname, statbuf);

	return result;
}
#endif

/* Actual glibc lstat() implementations */

int __lxstat(int ver, const char *pathname, struct stat *statbuf) {
	static int (*__real_lxstat)(int, const char *, struct stat *);
	int result = -1;

	if (!__real_lxstat)
		__real_lxstat = dlsym(RTLD_NEXT, "__lxstat");

	result = __xstat(ver, pathname, statbuf);

	if (result < 0)
		result = __real_lxstat(ver, pathname, statbuf);

	return result;
}

int __lxstat64(int ver, const char *pathname, struct stat64 *stat64buf) {
	static int (*__real_lxstat64)(int, const char *, struct stat64 *);
	int result = -1;

	if (!__real_lxstat64)
		__real_lxstat64 = dlsym(RTLD_NEXT, "__lxstat64");

	result = __xstat64(ver, pathname, stat64buf);

	if (result < 0)
		result = __real_lxstat64(ver, pathname, stat64buf);

	return result;
}

/* Not sure if needed -- I suspect it's probably implemented in terms of statx() anyway */

int fstatat(int dirfd, const char *pathname, struct stat *statbuf, int flags) {
	static int (*real_fstatat)(int, const char *, struct stat *, int);
	int result = -1;

	if (!real_fstatat)
		real_fstatat = dlsym(RTLD_NEXT, "fstatat");

	if (flags & AT_SYMLINK_NOFOLLOW)
		result = real_fstatat(dirfd, pathname, statbuf, flags & ~AT_SYMLINK_NOFOLLOW);

	if (result < 0)
		result = real_fstatat(dirfd, pathname, statbuf, flags);

	return result;
}

/* Used by coreutils */

int statx(int dirfd, const char *pathname, int flags, unsigned int mask, struct statx *statxbuf) {
	static int (*real_statx)(int, const char *, int, unsigned int, struct statx*);
	int result = -1;

	if (!real_statx)
		real_statx = dlsym(RTLD_NEXT, "statx");

	if (flags & AT_SYMLINK_NOFOLLOW)
		result = real_statx(dirfd, pathname, flags & ~AT_SYMLINK_NOFOLLOW, mask, statxbuf);

	if (result < 0)
		result = real_statx(dirfd, pathname, flags, mask, statxbuf);

	return result;
}
