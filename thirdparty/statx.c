// SPDX-License-Identifier: GPL-2.0-or-later
/* Test the statx() system call.
 *
 * Note that the output of this program is intended to look like the output of
 * /bin/stat where possible.
 *
 * Copyright (C) 2015 Red Hat, Inc. All Rights Reserved.
 * Written by David Howells (dhowells@redhat.com)
 */

#define _GNU_SOURCE
#define _ATFILE_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <ctype.h>
#include <errno.h>
#include <time.h>
#include <sys/syscall.h>
#include <sys/types.h>
#include <linux/stat.h>
#include <linux/fcntl.h>
#define statx foo
#define statx_timestamp foo_timestamp
#include <sys/stat.h>
#undef statx
#undef statx_timestamp

#define AT_STATX_SYNC_TYPE	0x6000
#define AT_STATX_SYNC_AS_STAT	0x0000
#define AT_STATX_FORCE_SYNC	0x2000
#define AT_STATX_DONT_SYNC	0x4000

#ifndef __NR_statx
#define __NR_statx -1
#endif

static __attribute__((unused))
ssize_t statx(int dfd, const char *filename, unsigned flags,
	      unsigned int mask, struct statx *buffer)
{
	return syscall(__NR_statx, dfd, filename, flags, mask, buffer);
}

static void print_time(const char *field, struct statx_timestamp *ts)
{
	struct tm tm;
	time_t tim;
	char buffer[100];
	int len;

	tim = ts->tv_sec;
	if (!localtime_r(&tim, &tm)) {
		perror("localtime_r");
		exit(1);
	}
	len = strftime(buffer, 100, "%F %T", &tm);
	if (len == 0) {
		perror("strftime");
		exit(1);
	}
	printf("%s", field);
	fwrite(buffer, 1, len, stdout);
	printf(".%09u", ts->tv_nsec);
	len = strftime(buffer, 100, "%z", &tm);
	if (len == 0) {
		perror("strftime2");
		exit(1);
	}
	fwrite(buffer, 1, len, stdout);
	printf("\n");
}

static void dump_statx(struct statx *stx)
{
	char buffer[256], ft = '?';

	printf(" ");
	if (stx->stx_mask & STATX_SIZE)
		printf(" Size: %-15llu", (unsigned long long)stx->stx_size);
	if (stx->stx_mask & STATX_BLOCKS)
		printf(" Blocks: %-10llu", (unsigned long long)stx->stx_blocks);
	printf(" IO Block: %-6llu", (unsigned long long)stx->stx_blksize);
	if (stx->stx_mask & STATX_TYPE) {
		switch (stx->stx_mode & S_IFMT) {
		case S_IFIFO:	printf("  FIFO\n");			ft = 'p'; break;
		case S_IFCHR:	printf("  character special file\n");	ft = 'c'; break;
		case S_IFDIR:	printf("  directory\n");		ft = 'd'; break;
		case S_IFBLK:	printf("  block special file\n");	ft = 'b'; break;
		case S_IFREG:	printf("  regular file\n");		ft = '-'; break;
		case S_IFLNK:	printf("  symbolic link\n");		ft = 'l'; break;
		case S_IFSOCK:	printf("  socket\n");			ft = 's'; break;
		default:
			printf(" unknown type (%o)\n", stx->stx_mode & S_IFMT);
			break;
		}
	} else {
		printf(" no type\n");
	}

	sprintf(buffer, "%02x:%02x", stx->stx_dev_major, stx->stx_dev_minor);
	printf("Device: %-15s", buffer);
	if (stx->stx_mask & STATX_INO)
		printf(" Inode: %-11llu", (unsigned long long) stx->stx_ino);
	if (stx->stx_mask & STATX_NLINK)
		printf(" Links: %-5u", stx->stx_nlink);
	if (stx->stx_mask & STATX_TYPE) {
		switch (stx->stx_mode & S_IFMT) {
		case S_IFBLK:
		case S_IFCHR:
			printf(" Device type: %u,%u",
			       stx->stx_rdev_major, stx->stx_rdev_minor);
			break;
		}
	}
	printf("\n");

	if (stx->stx_mask & STATX_MODE)
		printf("Access: (%04o/%c%c%c%c%c%c%c%c%c%c)  ",
		       stx->stx_mode & 07777,
		       ft,
		       stx->stx_mode & S_IRUSR ? 'r' : '-',
		       stx->stx_mode & S_IWUSR ? 'w' : '-',
		       stx->stx_mode & S_IXUSR ? 'x' : '-',
		       stx->stx_mode & S_IRGRP ? 'r' : '-',
		       stx->stx_mode & S_IWGRP ? 'w' : '-',
		       stx->stx_mode & S_IXGRP ? 'x' : '-',
		       stx->stx_mode & S_IROTH ? 'r' : '-',
		       stx->stx_mode & S_IWOTH ? 'w' : '-',
		       stx->stx_mode & S_IXOTH ? 'x' : '-');
	if (stx->stx_mask & STATX_UID)
		printf("Uid: %5d   ", stx->stx_uid);
	if (stx->stx_mask & STATX_GID)
		printf("Gid: %5d\n", stx->stx_gid);

	if (stx->stx_mask & STATX_ATIME)
		print_time("Access: ", &stx->stx_atime);
	if (stx->stx_mask & STATX_MTIME)
		print_time("Modify: ", &stx->stx_mtime);
	if (stx->stx_mask & STATX_CTIME)
		print_time("Change: ", &stx->stx_ctime);
	if (stx->stx_mask & STATX_BTIME)
		print_time(" Birth: ", &stx->stx_btime);

	/* Print supported attributes in short format */
	if (stx->stx_attributes_mask) {
		static char attr_flag[64] = {
			[2] = 'c', /* compressed */
			[4] = 'i', /* immutable */
			[5] = 'a', /* append-only */
			[6] = 'd', /* no-dump */
			[11] = 'e', /* encrypted */
			[12] = 'm', /* automount */
			[13] = 'r', /* mount-root */
			[20] = 'v', /* fs-verity */
		};

		printf("Attributes: 0x%016llx (", (unsigned long long)stx->stx_attributes);
		for (int bit = 0; bit < 64; bit++) {
			unsigned long long mbit = 1ULL << bit;
			if (stx->stx_attributes_mask & mbit) {
				putchar((stx->stx_attributes & mbit) ? attr_flag[bit] : '-');
			}
		}
		printf(")\n");
	}

	/* Print in verbose format */
	if (stx->stx_attributes_mask) {
		static char *attr_name[64] = {
			[2] = "compressed",
			[4] = "immutable",
			[5] = "append",
			[6] = "nodump",
			[11] = "encrypted",
			[12] = "automount",
			[13] = "mount_root",
			[20] = "fsverity",
		};
		int count = 0;

		printf("Attributes");
		for (int bit = 0; bit < 64; bit++) {
			if (stx->stx_attributes & (1ULL << bit)) {
				printf(count++ ? ", " : ": ");
				printf("%s(%d)", attr_name[bit] ?: "unknown", bit);
			}
		}
		printf(count ? "\n" : ": (none)\n");
	}
}

static void dump_hex(unsigned long long *data, int from, int to)
{
	unsigned offset, print_offset = 1, col = 0;

	from /= 8;
	to = (to + 7) / 8;

	for (offset = from; offset < to; offset++) {
		if (print_offset) {
			printf("%04x: ", offset * 8);
			print_offset = 0;
		}
		printf("%016llx", data[offset]);
		col++;
		if ((col & 3) == 0) {
			printf("\n");
			print_offset = 1;
		} else {
			printf(" ");
		}
	}

	if (!print_offset)
		printf("\n");
}

int main(int argc, char **argv)
{
	struct statx stx;
	int ret, raw = 0, atflag = AT_SYMLINK_NOFOLLOW;

	unsigned int mask = STATX_ALL;

	for (argv++; *argv; argv++) {
		if (strcmp(*argv, "-F") == 0) {
			atflag &= ~AT_STATX_SYNC_TYPE;
			atflag |= AT_STATX_FORCE_SYNC;
			continue;
		}
		if (strcmp(*argv, "-D") == 0) {
			atflag &= ~AT_STATX_SYNC_TYPE;
			atflag |= AT_STATX_DONT_SYNC;
			continue;
		}
		if (strcmp(*argv, "-L") == 0) {
			atflag &= ~AT_SYMLINK_NOFOLLOW;
			continue;
		}
		if (strcmp(*argv, "-O") == 0) {
			mask &= ~STATX_BASIC_STATS;
			continue;
		}
		if (strcmp(*argv, "-A") == 0) {
			atflag |= AT_NO_AUTOMOUNT;
			continue;
		}
		if (strcmp(*argv, "-R") == 0) {
			raw = 1;
			continue;
		}

		memset(&stx, 0xbf, sizeof(stx));
		ret = statx(AT_FDCWD, *argv, atflag, mask, &stx);
		printf("statx(%s) = %d\n", *argv, ret);
		if (ret < 0) {
			perror(*argv);
			exit(1);
		}

		if (raw)
			dump_hex((unsigned long long *)&stx, 0, sizeof(stx));

		dump_statx(&stx);
	}
	return 0;
}
