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

int main(int argc, char **argv) {
	const char sysctl[] = "/proc/sys/dev/tty/legacy_tiocsti";
	char *term = NULL;
	char *text = NULL;
	int fd;

	if (argc != 3) {
		printf("Usage: %s ttydev text\n", "writevt");
		return 2;
	}

	term = argv[1];
	text = argv[2];

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
	if (fd >= 0) {
		while (*text) {
			if (ioctl(fd, TIOCSTI, text)) {
				err(1, "ioctl(TIOCSTI) failed");
			}
			text++;
		}
		close(fd);
	} else {
		err(1, "could not open %s", term);
	}

	return 0;
}
