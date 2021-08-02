#if 0
src = $(MAKEFILE_LIST)
app = $(basename $(src))

$(app): CFLAGS = $(shell pkg-config --cflags fuse3) -Wall
$(app): LDLIBS = $(shell pkg-config --libs fuse3)
$(app): $(src)

define source
#endif

/* slashn -- FUSE filesystem for /n, translating /n/HOST to /net/HOST/home/USER
 * (or more precisely, /net/HOST/HOME_OF_USER) dynamically for any hostname and
 * any locally known username.
 *
 * (/net is of course expected to be an autofs mount.)
 */

#define FUSE_USE_VERSION 35

#include <errno.h>
#include <fuse.h>
#include <pwd.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/utsname.h>

const int max_name_len = 16;

static int slashn_getattr(path, stbuf, fi)
	const char *path;
	struct stat *stbuf;
	struct fuse_file_info *fi;
{
	if (strlen(path) > max_name_len)
		return -ENOENT;

	memset(stbuf, 0, sizeof(struct stat));
	if (strcmp(path, "/") == 0) {
		stbuf->st_mode = S_IFDIR | 0755;
		stbuf->st_nlink = 2;
	} else {
		stbuf->st_mode = S_IFLNK | 0777;
		stbuf->st_nlink = 1;
	}
	return 0;
}

static int slashn_readlink(path, outbuf, maxsz)
	const char *path;
	char *outbuf;
	size_t maxsz;
{
	static struct utsname ut;
	struct fuse_context *ctx;
	struct passwd pw, *pwr;
	char pwbuf[16384];

	if (!ut.sysname[0])
		uname(&ut);

	ctx = fuse_get_context();
	getpwuid_r(ctx->uid, &pw, pwbuf, sizeof(pwbuf), &pwr);

	if (!pwr)
		return -ENODATA;
	else if (strcmp(path+1, ut.nodename) == 0)
		snprintf(outbuf, maxsz, "%s", pwr->pw_dir);
	else
		snprintf(outbuf, maxsz, "/net/%s%s", path+1, pwr->pw_dir);

	return 0;
}

static int slashn_readdir(path, buf, filler, offset, fi, flags)
	const char *path;
	void *buf;
	fuse_fill_dir_t filler;
	off_t offset;
	struct fuse_file_info *fi;
	enum fuse_readdir_flags flags;
{
	filler(buf, ".", NULL, 0, 0);
	filler(buf, "..", NULL, 0, 0);
	return 0;
}

static const struct fuse_operations slashn_ops = {
	.getattr = slashn_getattr,
	.readlink = slashn_readlink,
	.readdir = slashn_readdir,
};

int main(argc, argv)
	int argc;
	char *argv[];
{
	return fuse_main(argc, argv, &slashn_ops, NULL);
}

#if 0
endef
#endif
