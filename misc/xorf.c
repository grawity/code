#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>

#define BUFSIZE 1024

void usage(void) {
	fprintf(stderr,
		"Usage: xors <file1> <file2>\n");
	exit(2);
}

void croak(char *msg) {
	fprintf(stderr, "error: %s: %m\n", msg);
	exit(1);
}

int main(int argc, char *argv[]) {
	char *fileA, *fileB;
	int fdA, fdB;
	unsigned char bufA[BUFSIZE], bufB[BUFSIZE], bufX[BUFSIZE];
	size_t lenA, lenB, lenX;
	unsigned i;

	if (argc != 3) {
		usage();
		return 2;
	}

	fileA = argv[1];
	fileB = argv[2];

	fdA = open(fileA, O_RDONLY);
	if (fdA < 0)
		croak("failed to open file 1");

	fdB = open(fileB, O_RDONLY);
	if (fdB < 0)
		croak("failed to open file 2");

	for (;;) {
		lenA = read(fdA, bufA, BUFSIZE);
		lenB = read(fdB, bufB, BUFSIZE);

		if (lenA <= 0 || lenB <= 0)
			break;

		lenX = (lenA < lenB) ? lenA : lenB;

		for (i = 0; i < BUFSIZE; i++)
			bufX[i] = bufA[i] ^ bufB[i];

		write(1, bufX, lenX);
	}

	return 0;
}

