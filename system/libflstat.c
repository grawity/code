/* Preload library to magically resolve symlinks (to be used for sftp-server
 * when dealing with symlink-incapable clients) */

#define _GNU_SOURCE
#include <dlfcn.h>
#include <sys/stat.h>
#include <fcntl.h> /* AT_* */

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
