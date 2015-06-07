#include <err.h>
#include <stdbool.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

enum {
	None,
	Escape,
	HexEscape,
	OctEscape
};

const char escapes[256] = {
	['a'] = '\a',
	['b'] = '\b',
	['f'] = '\f',
	['n'] = '\n',
	['r'] = '\r',
	['t'] = '\t',
	['v'] = '\v',
	/* `echo` compatibility; */
	['e'] = '\033',
	/* needed for keep_backslash mode: */
	['\''] = '\'',
	['\"'] = '\"',
	['\\'] = '\\',
};

bool keep_backslash = false;
bool warn_bad_escapes = true;
bool allow_long_x = false;

static int htoi(char ch) {
	switch (ch) {
	case '0'...'9': return ch - '0';
	case 'a'...'f': return ch - 'a' + 10;
	case 'A'...'F': return ch - 'A' + 10;
	default:        return -1;
	}
}

static void putchar_utf8(int ch) {
	if (ch < 0x80) {
		putchar(ch);
	} else if (ch < 0x800) {
		putchar(0xC0 | ((ch >>  6) & 0xFF));
		putchar(0x80 | ((ch >>  0) & 0x3F));
	} else if (ch < 0x10000) {
		putchar(0xE0 | ((ch >> 12) & 0xFF));
		putchar(0x80 | ((ch >>  6) & 0x3F));
		putchar(0x80 | ((ch >>  0) & 0x3F));
	} else if (ch < 0x110000) {
		putchar(0xF0 | ((ch >> 18) & 0xFF));
		putchar(0x80 | ((ch >> 12) & 0x3F));
		putchar(0x80 | ((ch >>  6) & 0x3F));
		putchar(0x80 | ((ch >>  0) & 0x3F));
	} else {
		putchar_utf8(0xFFFD);
	}
}

static void process(FILE *fp, char *fn) {
	int ch, state = None, letter,
	    acc = 0, len = 0, maxlen = 0, val;
	size_t pos = 0;

#define fwarnx(fmt, ...) \
	if (warn_bad_escapes) { \
		warnx("%s:%lu: " fmt, fn, pos, __VA_ARGS__); \
	}

	while ((ch = getc(fp)) != EOF && ++pos) {
		switch (state) {
		case None:
			if (ch == '\\')
				state = Escape;
			else
				putchar(ch);
			break;
		case Escape:
			switch (ch) {
			case 'x':
			case 'u':
			case 'U':
				acc = 0;
				len = 0;
				letter = ch;
				maxlen = (ch == 'x') ? 2 :
				         (ch == 'u') ? 4 :
				         (ch == 'U') ? 8 : -1;
				state = HexEscape;
				break;
			case '0'...'7':
				acc = htoi(ch);
				len = 1;
				maxlen = 3;
				state = OctEscape;
				break;
			default:
				if (escapes[ch])
					putchar(escapes[ch]);
				else {
					fwarnx("unknown escape \\%c", ch);
					if (keep_backslash)
						putchar('\\');
					putchar(ch);
				}
				state = None;
			}
			break;
		case HexEscape:
			if (ch == '{' && len == 0 && allow_long_x) {
				maxlen = -1;
				break;
			}

			if (ch == '}' && maxlen == -1) {
				putchar_utf8(acc);
				state = None;
				break;
			}

			val = htoi(ch);
			if (val >= 0) {
				acc = (acc << 4) | val;
				if (++len == maxlen) {
					(letter == 'x') ? putchar(acc)
					                : putchar_utf8(acc);
					state = None;
				}
			} else {
				if (len)
					(letter == 'x') ? putchar(acc)
					                : putchar_utf8(acc);
				else {
					fwarnx("missing hex digit for \\%c", letter);
					putchar('\\');
					putchar(letter);
				}
				ungetc(ch, fp);
				state = None;
			}
			break;
		case OctEscape:
			val = htoi(ch);
			if (val >= 0 && val <= 7) {
				acc = (acc << 3) | val;
				if (++len == maxlen) {
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

	switch (state) {
		case Escape:
			putchar('\\');
			break;
		case HexEscape:
		case OctEscape:
			if (len)
				putchar_utf8(acc);
			else {
				fwarnx("missing hex digit for \\%c", letter);
				putchar('\\');
				putchar(letter);
			}
			break;
	}

#undef fwarnx

}

static int usage(void) {
	printf("Usage: unescape [-a text] [-bqx] [files...]\n");
	printf("\n");
	printf("  -a TEXT   use TEXT as input rather than file/stdin\n");
	printf("  -b        keep backslashes in unknown escapes (like `echo`)\n");
	printf("            (the default is to discard them, like C/C++)\n");
	printf("  -q        stay quiet about unknown or truncated escapes\n");
	printf("  -x        allow Perl-style \\x{...} for Unicode codepoints\n");
	printf("\n");
	return 2;
}

int main(int argc, char *argv[]) {
	int i, r = 0, opt;
	char *data = NULL;
	char *fn;
	FILE *fp;

	while ((opt = getopt(argc, argv, "a:bqx")) != -1) {
		switch (opt) {
		case 'a':
			data = optarg;
			break;
		case 'b':
			keep_backslash = true;
			break;
		case 'q':
			warn_bad_escapes = false;
			break;
		case 'x':
			allow_long_x = true;
			break;
		default:
			return usage();
		}
	}

	argc -= optind-1;
	argv += optind-1;

	if (data) {
		fp = fmemopen(data, strlen(data), "rb");
		process(fp, "stdin");
		fclose(fp);
	}
	else if (argc <= 1) {
		process(stdin, "stdin");
	}
	else {
		for (i = 1; i < argc; i++) {
			fn = argv[i];
			if (!strcmp(fn, "-"))
				fp = stdin, fn = "stdin";
			else
				fp = fopen(fn, "rb");
			if (!fp) {
				warn("failed to open %s", fn);
				r = 1;
				continue;
			}
			process(fp, fn);
			if (fp != stdin)
				fclose(fp);
		}
	}

	return r;
}
