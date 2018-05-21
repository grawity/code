#include <err.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

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
	char *key;
	size_t buflen;
	unsigned char buf[BUFSIZE];
	unsigned keylen;
	unsigned i, k = 0;

	if (argc != 2)
		errx(2, "usage: xor <key>|0x<hexkey>");

	if (!strncmp(argv[1], "0x", 2)) {
		char *src, *dst, *end;
		unsigned int u;

		if (strlen(argv[1]) % 2)
			errx(1, "key truncated");
		src = argv[1] + 2;
		keylen = strlen(src) / 2;
		key = malloc(keylen);
		dst = key;
		end = key + keylen;
		while (dst < end && sscanf(src, "%2x", &u) == 1) {
			*dst++ = u;
			src += 2;
		}
		keylen = dst-key;
	} else {
		key = argv[1];
		keylen = strlen(key);
	}

	while ((buflen = read(0, buf, BUFSIZE))) {
		for (i = 0; i < buflen; i++) {
			k %= keylen;
			buf[i] ^= key[k++];
		}
		swrite(1, buf, buflen);
	}

	return 0;
}
