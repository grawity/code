#define _XOPEN_SOURCE 500

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
		fprintf(stderr, "Missing function\n");
		return 2;
	}
	else if (streq(cmd, "getpgid")) {
		pid_t pid;
		if (argc < 3)
			pid = 0;
		else {
			pid = atoi(argv[++i]);
			if (!pid)
				return 2;
		}
		pid_t pgid = getpgid(pid);
		if (pgid < 0) {
			perror("getpgid");
			return 1;
		} else
			printf("%d\n", pgid);
	}
	else if (streq(cmd, "getsid")) {
		pid_t pid;
		if (argc < 3)
			pid = 0;
		else {
			pid = atoi(argv[++i]);
			if (!pid)
				return 2;
		}
		pid_t pgid = getsid(pid);
		if (pgid < 0) {
			perror("getsid");
			return 1;
		} else
			printf("%d\n", pgid);
	}
	else if (streq(cmd, "pause")) {
		pause();
	}
	else if (streq(cmd, "wait")) {
		pid_t pid;
		char path[20]; // enough for /proc/ + 32-bit PID
		if (argc < 3) {
			fprintf(stderr, "Missing argument\n");
			return 2;
		} else {
			pid = atoi(argv[++i]);
			if (!pid)
				return 2;
		}
		sprintf(path, "/proc/%d", pid);
		while (access(path, F_OK) == 0)
			sleep(1);
		if (errno == ENOENT)
			return 0;
		else {
			perror("access");
			return 1;
		}
	}
	else {
		fprintf(stderr, "Unknown function '%s'\n", cmd);
	}

	return 2;
}
