#include <stdio.h>

enum {
	None,
	Escape,
	HexEscape,
	OctEscape
};

char escapes[256] = {
	['0'] = '\0',
	['a'] = '\a',
	['b'] = '\b',
	['f'] = '\f',
	['n'] = '\n',
	['r'] = '\r',
	['t'] = '\t',
	['v'] = '\v',
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

void putchar_utf8(int ch) {
	if (ch < 0x80) {
		putchar(ch);
	} else if (ch < 0x800) {
		putchar((ch >> 6) | 0xC0);
		putchar((ch & 0x3F) | 0x80);
	} else if (ch < 0x10000) {
		putchar((ch >> 12) | 0xE0);
		putchar(((ch >> 6) & 0x3F) | 0x80);
		putchar((ch & 0x3F) | 0x80);
	} else if (ch < 0x110000) {
		putchar((ch >> 18) | 0xF0);
		putchar(((ch >> 12) & 0x3F) | 0x80);
		putchar(((ch >> 6) & 0x3F) | 0x80);
		putchar((ch & 0x3F) | 0x80);
	}
}

void process(FILE *f) {
	int c, state = None, acc, len, maxlen, val;

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
				maxlen = 2;
				state = HexEscape;
				break;
			case 'u':
				acc = len = 0;
				maxlen = 4;
				state = HexEscape;
				break;
			case 'U':
				acc = len = 0;
				maxlen = 8;
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
					putchar(c);
				}
				state = None;
			}
			break;
		case HexEscape:
			val = htoi(c);
			if (val >= 0) {
				acc = (acc << 4) | val;
				if (++len == maxlen) {
					putchar_utf8(acc);
					state = None;
				}
			} else {
				if (len) {
					putchar_utf8(acc);
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
