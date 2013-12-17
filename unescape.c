#include <stdio.h>
#include <unistd.h>

enum {
	None,
	Escape,
	HexEscape,
	OctEscape
};

const char escapes[256] = {
	['0'] = '\0',
	['a'] = '\a',
	['b'] = '\b',
	['f'] = '\f',
	['n'] = '\n',
	['r'] = '\r',
	['t'] = '\t',
	['v'] = '\v',
};

int keep_backslash = 0;

static int htoi(char ch) {
	switch (ch) {
	case '0'...'9':
		return ch - '0';
	case 'a'...'f':
		return ch - 'a' + 10;
	case 'A'...'F':
		return ch - 'A' + 10;
	default:
		return -1;
	}
}

static void putchar_utf8(int ch) {
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

static void process(FILE *fp) {
	int ch, state = None, acc, len, maxlen, val;

	while ((ch = getc(fp)) != EOF) {
		switch (state) {
		case None:
			if (ch == '\\') {
				state = Escape;
			} else {
				putchar(ch);
			}
			break;
		case Escape:
			switch (ch) {
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
				acc = htoi(ch);
				len = 1;
				state = OctEscape;
				break;
			default:
				if (escapes[ch]) {
					putchar(escapes[ch]);
				} else {
					if (keep_backslash)
						putchar('\\');
					putchar(ch);
				}
				state = None;
			}
			break;
		case HexEscape:
			val = htoi(ch);
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
				ungetc(ch, fp);
				state = None;
			}
			break;
		case OctEscape:
			val = htoi(ch);
			if (val >= 0 && val < 8) {
				acc = (acc << 3) | val;
				if (++len == 3) {
					putchar(acc);
					state = None;
				}
			} else {
				putchar(acc);
				ungetc(ch, fp);
				state = None;
			}
			break;
		}
	}
}

int main(int argc, char *argv[]) {
	int i, r = 0, opt;
	FILE *fp;

	while ((opt = getopt(argc, argv, "b")) != -1) {
		switch (opt) {
		case 'b':
			keep_backslash = 1;
			break;
		}
	}

	argc -= optind-1;
	argv += optind-1;

	if (argc <= 1) {
		process(stdin);
	} else {
		for (i = 1; i < argc; i++) {
			if (!strcmp(argv[i], "-"))
				fp = stdin;
			else
				fp = fopen(argv[i], "rb");
			if (!fp) {
				fprintf(stderr, "error: failed to open %s: %m\n", argv[i]);
				r = 1;
				continue;
			}
			process(fp);
			if (fp != stdin)
				fclose(fp);
		}
	}

	return r;
}
