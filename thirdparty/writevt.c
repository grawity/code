/*
 * Mostly ripped off of console-tools' writevt.c
 */

#include <err.h>
#include <errno.h>
#include <stdio.h>
#include <fcntl.h>
#include <termios.h>
#include <sys/ioctl.h>
#include <unistd.h>

const char sysctl[] = "/proc/sys/dev/tty/legacy_tiocsti";

static int usage() {
	printf("Usage: %s ttydev text\n", "writevt");
	return 2;
}

int main(int argc, char **argv) {
	int fd, argi;
	char *term = NULL;
	char *text = NULL;

	argi = 1;

	if (argi < argc)
		term = argv[argi++];
	else {
		warnx("no tty specified");
		return usage();
	}

	if (argi < argc)
		text = argv[argi++];
	else {
		warnx("no text specified");
		return usage();
	}

	if (argi != argc) {
		warnx("too many arguments");
		return usage();
	}

	fd = open(sysctl, O_WRONLY);
	if (fd >= 0) {
		if (write(fd, "1", sizeof "1") < 0) {
			err(1, "could not write to %s", sysctl);
		}
		close(fd);
	} else if (errno == ENOENT) {
		// ignore; pre-6.2 kernel always had TIOCSTI enabled
	} else {
		err(1, "could not open %s", sysctl);
	}

	fd = open(term, O_RDONLY);
	if (fd < 0) {
		err(1, "could not open %s", term);
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
