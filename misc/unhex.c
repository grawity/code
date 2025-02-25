/* unhex -- convert data from hexadecimal */
#define _GNU_SOURCE /* for fmemopen */
#include <stdio.h>
#include <string.h>
#include <unistd.h>

int main(int argc, char *argv[]) {
	FILE *input = stdin;
	int opt;

	char c = 0, d = 0;
	int odd = 0;

	while ((opt = getopt(argc, argv, "a:")) != -1) {
		switch (opt) {
		case 'a':
			input = fmemopen(optarg, strlen(optarg), "r");
			break;
		default:
			return 2;
		}
	}

	if (argc > optind) {
		fprintf(stderr, "unhex: too many arguments\n");
		return 2;
	}

	for (;;) {
		c = fgetc(input);

		if (c == EOF) break;
		else if (c >= '0' && c <= '9') c -= '0';
		else if (c >= 'a' && c <= 'f') c -= 'a' - 10;
		else if (c >= 'A' && c <= 'F') c -= 'A' - 10;
		else if (c == 'x' && odd && d == 0) { odd = 0; continue; }
		else continue;

		if (odd)
			fputc(d | c, stdout);
		else
			d = c << 4;

		odd = !odd;
	}

	if (odd)
		fprintf(stderr, "unhex: odd number of input nibbles\n");

	return odd;
}
