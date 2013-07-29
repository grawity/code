#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>

#define BUFSIZE 1024

void usage(void) {
	fprintf(stderr,
		"Usage: xors <key> <increment>\n");
	exit(2);
}

int main(int argc, char *argv[]) {
	unsigned char buf[BUFSIZE];
	size_t buflen;
	int i, key = 0, incr = 1;

	if (argc == 3) {
		key = atoi(argv[1]);
		incr = atoi(argv[2]);
	} else {
		usage();
	}

	while ((buflen = read(0, buf, BUFSIZE))) {
		for (i = 0; i < buflen; i++) {
			key %= 256;
			buf[i] ^= key;
			key += incr;
		}
		write(1, buf, buflen);
	}

	return 0;
}
