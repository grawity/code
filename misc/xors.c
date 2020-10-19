#include <err.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>

#define BUFSIZE 1024

void swrite(int fd, const void *buf, size_t nb) {
	ssize_t nw, off = 0;

	while (nb > 0) {
		nw = write(fd, buf + off, nb - off);
		if (nw < 0)
			err(1, "write failed");
		nb -= nw;
		off += nw;
	}
}

int main(int argc, char *argv[]) {
	unsigned char buf[BUFSIZE];
	size_t buflen;
	unsigned i, key = 0, incr = 1, step = 1;

	if (argc < 1)
		errx(2, "usage: xors <key> [<incr> [<step>]]");

	if (argc > 1) key = atoi(argv[1]);
	if (argc > 2) incr = atoi(argv[2]);
	if (argc > 3) step = atoi(argv[3]);

	while ((buflen = read(0, buf, BUFSIZE))) {
		for (i = 0; i < buflen; i++) {
			if (i > 0 && i % step == 0)
				key += incr;
			key %= 256;
			buf[i] ^= key;
		}
		swrite(1, buf, buflen);
	}

	return 0;
}
