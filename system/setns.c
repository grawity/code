#define _GNU_SOURCE
#include <sched.h>
#include <stdio.h>
#include <fcntl.h>
#include <stdlib.h>
#include <unistd.h>

void usage(void) {
	fprintf(stderr,
	"Usage: setns <ns> <cmd> [args...]\n"
	"\n"
	"<ns> may be either a path to a namespace (/proc/PID/ns/TYPE), or\n"
	"a decimal file descriptor of an already open namespace.\n"
	"(The file descriptor will, in both cases, be closed after joining.)\n");
}

int main(int argc, char *argv[]) {
	int r, fd;
	char *nsname, **execargv;
	char *endptr;

	if (argc < 3) {
		fprintf(stderr, "setns: command not specified\n");
		usage();
		return 2;
	}

	nsname = argv[1];
	execargv = argv+2;

	if (*nsname == '/' || *nsname == '.') {
		fd = open(nsname, O_RDONLY|O_NOCTTY|O_CLOEXEC);
		if (fd < 0) {
			perror("setns: open");
			return 1;
		}
	} else {
		fd = (int) strtol(nsname, &endptr, 10);
		if (*endptr != '\0') {
			fprintf(stderr, "setns: path must be absolute");
			return 1;
		}
	}

	r = setns(fd, 0);
	if (r < 0) {
		perror("setns");
		return 1;
	}

	r = close(fd);
	if (r < 0) {
		perror("close");
		return 1;
	}

	r = execvp(execargv[0], execargv);
	if (r < 0) {
		perror("execvp");
		return 1;
	}

	return 0;
}
