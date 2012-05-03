/*
 * Runs a program using the UNAME26 personality flag, for compatibility
 * with programs expecting 2.6.* kernel version numbers.
 *
 * See Linux commit be27425dcc516fd08245b047ea57f83b8f6f0903.
 *
 * Adapted from ftp://ftp.kernel.org/pub/linux/kernel/people/ak/uname26/uname26.c
 */

#include <stdio.h>
#include <sys/personality.h>
#include <unistd.h>

/* Bug emulation flags, taken from <linux/personality.h> */

enum {
	UNAME26		= 0x0020000,
};

int main(int argc, char *argv[]) {
	int r;

	r = personality(UNAME26);
	if (r < 0) {
		perror("personality");
		return 1;
	}

	argv++;
	r = execvp(argv[0], argv);
	if (r < 0) {
		perror("exec");
		return 1;
	}

	return 0;
}
