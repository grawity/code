#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/wait.h>
#include <string.h>

static void usage() {
	fprintf(stderr, "usage: spawn [-w] <command> [args]\n");
	exit(2);
}

int main(int argc, char *argv[]) {
	int do_wait = 0;
	char **cmd = &argv[1];

	// very quick and dirty
	if (!cmd[0]) usage();
	if (!strcmp(cmd[0], "-w")) {
		do_wait = 1;
		cmd++;
	}
	if (!cmd[0]) usage();

	switch (fork()) {
	case 0:
		if (setsid() < 0) {
			perror("setsid");
			return 1;
		}
		if (execvp(cmd[0], cmd) < 0) {
			perror("execvp");
			return 1;
		}
		return 0;
	case -1:
		perror("fork");
		return 1;
	default:
		if (do_wait)
			wait(NULL);
		return 0;
	}
}
