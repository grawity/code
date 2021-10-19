#include <stdio.h>
#include <string.h>
#include <unistd.h>

int main(int argc, char *argv[]) {
	FILE *input = stdin;
	int opt;
	int c;

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
		fprintf(stderr, "hex: too many arguments\n");
		return 2;
	}

	for (;;) {
		c = fgetc(input);
		if (c == EOF)
			break;
		fprintf(stdout, "%02x", (unsigned char) c);
	}

	return 0;
}
