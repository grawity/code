#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

static void usage() {
	fprintf(stderr, "usage: spawn <command> [args]\n");
	exit(2);
}

int main(int argc, char *argv[]) {
	if (argc < 2)
		usage();

	switch (fork()) {
	case 0:
		if (setsid() < 0) {
			perror("setsid");
			return 1;
		}
		if (execvp(argv[1], argv+1) < 0) {
			perror("execvp");
			return 1;
		}
		return 0;
	case -1:
		perror("fork");
		return 1;
	default:
		return 0;
	}
}
