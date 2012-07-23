#define _XOPEN_SOURCE 500

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
	else {
		fprintf(stderr, "Unknown function '%s'\n", cmd);
	}

	return 2;
}
