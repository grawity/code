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

void process(FILE *f) {
	int c, state = None, acc, len, val;

	while ((c = getc(f)) != EOF) {
		switch (state) {
		case None:
			if (c == '\\') {
				state = Escape;
			} else {
				putchar(c);
			}
			break;
		case Escape:
			switch (c) {
			case 'x':
				acc = len = 0;
				state = HexEscape;
				break;
			case '0'...'7':
				acc = htoi(c);
				len = 1;
				state = OctEscape;
				break;
			default:
				if (escapes[c]) {
					putchar(escapes[c]);
				} else {
					putchar('\\');
					putchar(c);
				}
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
				ungetc(c, f);
				state = None;
			}
			break;
		case OctEscape:
			val = htoi(c);
			if (val >= 0 && val < 8) {
				acc = (acc << 3) | val;
				if (++len == 3) {
					putchar(acc);
					state = None;
				}
			} else {
				if (len) {
					putchar(acc);
				} else {
					putchar('\\');
				}
				ungetc(c, f);
				state = None;
			}
			break;
		}
	}
}

int main(void) {
	process(stdin);

	return 0;
}
