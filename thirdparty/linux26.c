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

#define UNAME26 0x0020000

int main(int argc, char *argv[]) {
	int r;
	if ((r = personality(UNAME26)) < 0) {
		perror("personality");
		return r;
	}
	argv++;
	if ((r = execvp(argv[0], argv))) {
		perror("exec");
		return r;
	}
	return 0;
}
