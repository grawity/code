/*
 * Mostly ripped off of console-tools' writevt.c
 */

#include <errno.h>
#include <stdio.h>
#include <fcntl.h>
#include <termios.h>
#include <sys/ioctl.h>
#include <unistd.h>

char *progname;

const char sysctl[] = "/proc/sys/dev/tty/legacy_tiocsti";

static int usage() {
	printf("Usage: %s ttydev text\n", progname);
	return 2;
}

int main(int argc, char **argv) {
	int fd, argi;
	char *term = NULL;
	char *text = NULL;

	progname = argv[0];

	argi = 1;

	if (argi < argc)
		term = argv[argi++];
	else {
		fprintf(stderr, "%s: no tty specified\n", progname);
		return usage();
	}

	if (argi < argc)
		text = argv[argi++];
	else {
		fprintf(stderr, "%s: no text specified\n", progname);
		return usage();
	}

	if (argi != argc) {
		fprintf(stderr, "%s: too many arguments\n", progname);
		return usage();
	}

	fd = open(sysctl, O_WRONLY);
	if (fd >= 0) {
		if (write(fd, "1", sizeof "1") < 0) {
			perror(sysctl);
			fprintf(stderr, "%s: could not activate sysctl\n", progname);
			return 1;
		}
		close(fd);
	} else if (errno == ENOENT) {
		// ignore; pre-6.2 kernel always had TIOCSTI enabled
	} else {
		perror(sysctl);
		fprintf(stderr, "%s: could not activate sysctl\n", progname);
		return 1;
	}

	fd = open(term, O_RDONLY);
	if (fd < 0) {
		perror(term);
		fprintf(stderr, "%s: could not open tty\n", progname);
		return 1;
	}

	while (*text) {
		if (ioctl(fd, TIOCSTI, text)) {
			perror("ioctl");
			return 1;
		}
		text++;
	}

	return 0;
}
