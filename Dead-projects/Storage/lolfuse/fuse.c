#define _GNU_SOURCE /* avoid implicit declaration of *pt* functions */

#define FUSE_USE_VERSION 26

#include <fuse.h>
#include <fuse_opt.h>
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <string.h>
#include <stdint.h>
#include <errno.h>

#define zero(x) memset(x, 0, sizeof(*x))

struct list_head {
	struct list_head *prev;
	struct list_head *next;
	void *data;
};

static struct list_head dirs;

static void list_init(struct list_head *head) {
	head->next = head;
	head->prev = head;
}

static void list_add(struct list_head *new, struct list_head *head) {
	struct list_head *prev = head;
	struct list_head *next = head->next;
	next->prev = new;
	new->next = next;
	new->prev = prev;
	prev->next = new;
}

static void list_del(struct list_head *entry) {
	struct list_head *prev = entry->prev;
	struct list_head *next = entry->next;
	next->prev = prev;
	prev->next = next;
}

static int list_empty(const struct list_head *head) {
	return head->next == head;
}

static int count_components(const char *path) {
	int c = 0;
	path++;
	if (*path)
		c++;
	while (*path)
		if (*path++ == '/')
			c++;
	return c;
}

static int lol_getattr(const char *path, struct stat *st) {
	zero(st);
	if (!strcmp(path, "/")) {
		st->st_mode = S_IFDIR | 0755;
		return 0;
	} else if (!strcmp(path, "/foo")) {
		st->st_mode = S_IFBLK | 0666;
		st->st_rdev = makedev(1, 5);
		return 0;
	} else if (count_components(path) == 1) {
		st->st_mode = S_IFDIR | 0000;
		return 0;
	} else {
		return -ENOLINK;
	}
}

static int lol_opendir(const char *path, struct fuse_file_info *fi) {
	if (!strcmp(path, "/")) {
		return 0;
	} else if (count_components(path) == 1) {
		return 0;
	} else {
		return -ENONET;
	}
}

static int lol_readdir(const char *path, void *buf, fuse_fill_dir_t filler,
                       off_t offset, struct fuse_file_info *fi)
{
	if (count_components(path) <= 1) {
		filler(buf, ".", NULL, 0);
		filler(buf, "..", NULL, 0);
		filler(buf, "foo", NULL, 0);
		return 0;
	} else {
		return -ENOENT;
	}
}

static struct fuse_operations sshfs_oper = {
	.getattr    = lol_getattr,
	.opendir    = lol_opendir,
	.readdir    = lol_readdir,
};

int main(int argc, char *argv[])
{
	int res;
	struct fuse_args args = FUSE_ARGS_INIT(argc, argv);

	res = fuse_main(args.argc, args.argv, &sshfs_oper, NULL);

	fuse_opt_free_args(&args);
	return res;
}
