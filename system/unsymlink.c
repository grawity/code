/* Preload library to magically resolve symlinks (to be used for sftp-server
 * when dealing with symlink-incapable clients) */

#define _GNU_SOURCE
#include <dlfcn.h>
#include <sys/stat.h>
#include <fcntl.h> /* AT_* */
#include <syslog.h>

/* Additional hack to hide '.git' directory */

#if 1
#define XS_IFMT		0170000
#define XS_IFIFO	0010000
#define XS_IFCHR	0020000
#define XS_IFDIR	0040000
#define XS_IFBLK	0060000
#define XS_IFREG	0100000
#define XS_IFLNK	0120000
#define XS_IFSOCK	0140000
#define XS_IFWEIRD	0160000

#define BADMODE(m) (S_ISDIR(m) && (m & S_ISUID) && !(m & S_ISGID))
#define HACKMODE(m) if (result == 0 && BADMODE(m)) { m = S_IFSOCK; }
#else
#define HACKMODE(m)
#endif


#if 0
int lstat(const char *pathname, struct stat *statbuf) {
	static int (*real_lstat)(const char *, struct stat *);
	int result = -1;

	if (!real_lstat)
		real_lstat = dlsym(RTLD_NEXT, "lstat");

	result = stat(pathname, statbuf);

	if (result < 0)
		result = real_lstat(pathname, statbuf);

	HACKMODE(statbuf->st_mode);
	return result;
}
#endif

/* Actual glibc lstat() implementations */

int __lxstat(int ver, const char *pathname, struct stat *statbuf) {
	static int (*__real_lxstat)(int, const char *, struct stat *);
	int result = -1;

	syslog(LOG_DEBUG, "intercepted __lxstat('%s')", pathname);

	if (!__real_lxstat)
		__real_lxstat = dlsym(RTLD_NEXT, "__lxstat");

	result = __xstat(ver, pathname, statbuf);

	if (result < 0)
		result = __real_lxstat(ver, pathname, statbuf);

	HACKMODE(statbuf->st_mode);
	return result;
}

int __lxstat64(int ver, const char *pathname, struct stat64 *stat64buf) {
	static int (*__real_lxstat64)(int, const char *, struct stat64 *);
	int result = -1;

	syslog(LOG_DEBUG, "intercepted __lxstat64('%s')", pathname);

	if (!__real_lxstat64)
		__real_lxstat64 = dlsym(RTLD_NEXT, "__lxstat64");

	result = __xstat64(ver, pathname, stat64buf);

	if (result < 0)
		result = __real_lxstat64(ver, pathname, stat64buf);

	HACKMODE(stat64buf->st_mode);
	return result;
}

/* Not sure if needed -- I suspect it's probably implemented in terms of statx() anyway */

int fstatat(int dirfd, const char *pathname, struct stat *statbuf, int flags) {
	static int (*real_fstatat)(int, const char *, struct stat *, int);
	int result = -1;

	syslog(LOG_DEBUG, "intercepted fstatat('%s')", pathname);

	if (!real_fstatat)
		real_fstatat = dlsym(RTLD_NEXT, "fstatat");

	if (flags & AT_SYMLINK_NOFOLLOW)
		result = real_fstatat(dirfd, pathname, statbuf, flags & ~AT_SYMLINK_NOFOLLOW);

	if (result < 0)
		result = real_fstatat(dirfd, pathname, statbuf, flags);

	HACKMODE(statbuf->st_mode);
	return result;
}

/* Used by coreutils */

int statx(int dirfd, const char *pathname, int flags, unsigned int mask, struct statx *statxbuf) {
	static int (*real_statx)(int, const char *, int, unsigned int, struct statx*);
	int result = -1;

	syslog(LOG_DEBUG, "intercepted statx('%s')", pathname);

	if (!real_statx)
		real_statx = dlsym(RTLD_NEXT, "statx");

	if (flags & AT_SYMLINK_NOFOLLOW)
		result = real_statx(dirfd, pathname, flags & ~AT_SYMLINK_NOFOLLOW, mask, statxbuf);

	if (result < 0)
		result = real_statx(dirfd, pathname, flags, mask, statxbuf);

	HACKMODE(statxbuf->stx_mode);
	return result;
}
