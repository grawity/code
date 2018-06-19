#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/statvfs.h>

const int DEFAULT_FSID = 0;
const int DEFAULT_INODE = 0;

static int is_wanted_path(const char *path)
{
	const char *suffix[2] = {
		"/.dropbox/instance_db",
		"/.dropbox/instance1",
	};
	for (int i = 0; i < 2; i++) {
		if (strcmp(path + strlen(path) - strlen(suffix[i]), suffix[i]) == 0)
			return 1;
	}
	return 0;
}

int statvfs64(const char *path, struct statvfs64 *buf)
{
	static int (*real_statvfs64)(const char *, struct statvfs64 *);
	int result;
	if (!real_statvfs64)
		real_statvfs64 = dlsym(RTLD_NEXT, "statvfs64");
	result = real_statvfs64(path, buf);
	if (is_wanted_path(path)) {
		printf("libdropfox: statvfs64(): faking fsid of '%s'\n", path);
		printf("libdropfox: original fsid = 0x%llx\n", buf->f_fsid);
		buf->f_fsid = DEFAULT_FSID;
	}
	return result;
}

int __xstat64(int ver, const char *path, struct stat64 *buf)
{
	static int (*real___xstat64)(int, const char *, struct stat64 *);
	int result;
	if (!real___xstat64)
		real___xstat64 = dlsym(RTLD_NEXT, "__xstat64");
	result = real___xstat64(ver, path, buf);
	if (is_wanted_path(path)) {
		printf("libdropfox: __xstat64(): faking inode of '%s'\n", path);
		printf("libdropfox: original inode = 0x%llx\n", buf->st_ino);
		buf->st_ino = DEFAULT_INODE;
	}
	return result;
}

int __lxstat64(int ver, const char *path, struct stat64 *buf)
{
	static int (*real___lxstat64)(int, const char *, struct stat64 *);
	int result;
	if (!real___lxstat64)
		real___lxstat64 = dlsym(RTLD_NEXT, "__lxstat64");
	result = real___lxstat64(ver, path, buf);
	if (is_wanted_path(path)) {
		printf("libdropfox: __lxstat64(): faking inode of '%s'\n", path);
		printf("libdropfox: original inode = 0x%llx\n", buf->st_ino);
		buf->st_ino = DEFAULT_INODE;
	}
	return result;
}
