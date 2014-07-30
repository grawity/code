#include <stdio.h>

int unhex(char c) {
	if      (c >= '0' && c <= '9') return c - '0';
	else if (c >= 'a' && c <= 'f') return c - 'a' + 10;
	else if (c >= 'A' && c <= 'F') return c - 'A' + 10;
	else                           return -1;
}

void unescape(char *in, int nl) {
	int i, state = 0, nb, ch;

	for (i = 0; in[i]; ++i) {
		switch (state) {
		case 0:
			if (in[i] == '%')
				state = 1;
			else
				putchar(in[i]);
			break;
		case 1:
			nb = unhex(in[i]);
			if (nb < 0) {
				putchar(in[i]);
				state = 0;
			} else {
				ch = nb << 4;
				state = 2;
			}
			break;
		case 2:
			nb = unhex(in[i]);
			if (nb < 0)
				putchar(in[i]);
			else
				putchar(ch | nb);
			state = 0;
			break;
		}
	}

	if (nl)
		putchar('\n');
}

int main(int argc, char *argv[]) {
	char buf[512+1];
	int i, len;

	if (argc > 1) {
		for (i = 1; argv[i]; ++i)
			unescape(argv[i], 1);
	} else {
		while ((len = fread(buf, 1, 512, stdin)) > 0) {
			buf[len] = 0;
			unescape(buf, 0);
		}
	}

	return 0;
}
