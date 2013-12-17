#include <stdio.h>

enum {
	None,
	Escape,
	HexEscape,
	OctEscape
};

char escapes[256] = {
	['\\'] = '\\',
	['n'] = '\n',
	['r'] = '\r',
	['t'] = '\t',
};

int htoi(char c) {
	switch (c) {
	case '0'...'9':
		return c - '0';
	case 'a'...'f':
		return c - 'a' + 10;
	case 'A'...'F':
		return c - 'A' + 10;
	default:
		return -1;
	}
}

int ungetchar(char x) {
	return ungetc(x, stdin);
}

int main(void) {
	int c, state = None, acc, len, val;

	while ((c = getchar()) != EOF) {
		switch (state) {
		case None:
			if (c == '\\') {
				state = Escape;
			} else {
				putchar(c);
			}
			break;
		case Escape:
			if (c == 'x') {
				acc = len = 0;
				state = HexEscape;
			} else if (escapes[c]) {
				putchar(escapes[c]);
				state = None;
			} else {
				putchar('\\');
				putchar(c);
				state = None;
			}
			break;
		case HexEscape:
			val = htoi(c);
			if (val >= 0) {
				acc = (acc << 4) | val;
				if (++len == 2) {
					putchar(acc);
					state = None;
				}
			} else {
				if (len) {
					putchar(acc);
				} else {
					putchar('\\');
					putchar('x');
				}
				ungetchar(c);
				state = None;
			}
			break;
		}
	}

	return 0;
}
