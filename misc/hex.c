#include <stdio.h>

int main(void) {
	char c;

	for (;;) {
		c = fgetc(stdin);
		if (c == EOF)
			break;
		fprintf(stdout, "%02x", c);
	}
	return 0;
}
