#include <stdio.h>

int main(void) {
	char c, d;
	int ctr = 0;

	for (;;) {
		c = fgetc(stdin);

		if (c == EOF) break;
		else if (c >= '0' && c <= '9') c -= '0';
		else if (c >= 'a' && c <= 'f') c -= 'a' - 10;
		else if (c >= 'A' && c <= 'F') c -= 'A' - 10;
		else continue;

		if (ctr)
			fputc(d | c, stdout);
		else
			d = c << 4;

		ctr = !ctr;
	}

	if (ctr)
		fprintf(stderr, "unhex: odd number of input nibbles\n");

	return ctr;
}
