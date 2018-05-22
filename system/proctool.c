#if !defined(HAVE_SOLARIS)
#  define _XOPEN_SOURCE 700
#endif

#include <err.h>
#include <errno.h>
#include <stdio.h>
#include <string.h>
#include "util.h"
#include <unistd.h>
#include <stdlib.h>

int main(int argc, char *argv[]) {
	int i = 0;
	char *cmd = argv[++i];

	if (argc < 2) {
		errx(1, "missing subcommand");
	}
	else if (streq(cmd, "getpgid")) {
		pid_t pid, pgid;
		if (argc < 3) {
			pid = 0;
		} else {
			pid = atoi(argv[++i]);
			if (!pid)
				errx(2, "malformed PID: '%s'", argv[i]);
		}
		pgid = getpgid(pid);
		if (pgid < 0)
			err(1, "getpgid");
		printf("%lu\n", (unsigned long) pgid);
	}
	else if (streq(cmd, "getsid")) {
		pid_t pid, pgid;
		if (argc < 3) {
			pid = 0;
		} else {
			pid = atoi(argv[++i]);
			if (!pid)
				return 2;
		}
		pgid = getsid(pid);
		if (pgid < 0)
			err(1, "getsid");
		printf("%lu\n", (unsigned long) pgid);
	}
	else if (streq(cmd, "wait")) {
		pid_t pid;
		char path[32]; // enough for /proc/ + 32-bit PID
		int interval = 1;
		if (argc > 2) {
			pid = atoi(argv[++i]);
			if (!pid)
				errx(2, "malformed PID: '%s'", argv[i]);
		} else {
			errx(2, "missing PID argument");
		}
		if (argc > 3) {
			interval = atoi(argv[++i]);
			if (!interval)
				errx(2, "malformed interval: '%s'", argv[i]);
		}
		snprintf(path, sizeof(path), "/proc/%lu", (unsigned long) pid);
		while (access(path, F_OK) == 0)
			sleep(interval);
		if (errno == ENOENT)
			return 0;
		else
			err(1, "could not access '%s'", path);
	}
	else {
		errx(2, "unknown subcommand '%s'", cmd);
	}

	return 0;
}
