#include <err.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>

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
	char *fileA, *fileB;
	int fdA, fdB;
	unsigned char bufA[BUFSIZE], bufB[BUFSIZE], bufX[BUFSIZE];
	size_t lenA, lenB, lenX;
	unsigned i;

	if (argc != 3)
		errx(2, "usage: xorf <file1> <file2>");

	fileA = argv[1];
	fileB = argv[2];

	fdA = open(fileA, O_RDONLY);
	if (fdA < 0)
		err(1, "failed to open '%s'", fileA);

	fdB = open(fileB, O_RDONLY);
	if (fdB < 0)
		err(1, "failed to open '%s'", fileB);

	for (;;) {
		lenA = read(fdA, bufA, BUFSIZE);
		lenB = read(fdB, bufB, BUFSIZE);

		if (lenA <= 0 || lenB <= 0)
			break;

		lenX = (lenA < lenB) ? lenA : lenB;

		for (i = 0; i < BUFSIZE; i++)
			bufX[i] = bufA[i] ^ bufB[i];

		swrite(1, bufX, lenX);
	}

	return 0;
}
