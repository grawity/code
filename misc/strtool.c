/* strtool -- basic string manipulation helper for wmiirc */
#define _XOPEN_SOURCE
#include <err.h>
#include <locale.h>
#include <stdio.h>
#include <string.h>
#include <wchar.h>
#include "util.h"

#define LINESZ 4096

/* null-terminate a string at first \n */

static char * cut(char *line) {
	char *c;

	for (c = line; *c; c++) {
		if (*c == '\n') {
			*c = '\0';
			break;
		}
	}

	return c;
}

/* print line after first match */

int next_item(char *want, int wrap) {
	char a[LINESZ] = {0};
	char b[LINESZ] = {0};
	char *line[2] = {a, b};
	int n = 0, found = 0;

	for (;; n=1) {
		if (!fgets(line[n], LINESZ, stdin))
			break;

		cut(line[n]);

		if (found) {
			printf("%s\n", line[n]);
			return 0;
		} else if (!strcmp(line[n], want)) {
			found = 1;
		}
	}

	if (!found || !wrap || !n) {
		return 1;
	} else {
		printf("%s\n", line[0]);
		return 0;
	}
}

/* print line before first match */

int prev_item(char *want, int wrap) {
	char a[LINESZ] = {0};
	char b[LINESZ] = {0};
	char *line[2] = {a, b};
	int n = 0, count = 0;

	for (;; n=!n, ++count) {
		if (!fgets(line[n], LINESZ, stdin))
			return 1;

		cut(line[n]);

		if (!strcmp(line[n], want)) {
			if (count) {
				printf("%s\n", line[!n]);
				return 0;
			} else {
				break;
			}
		}
	}

	if (count || !wrap) {
		return 1;
	} else {
		while (fgets(line[n], LINESZ, stdin))
			;
		cut(line[n]);
		printf("%s\n", line[n]);
		return 0;
	}
}

/* remove text from end of the line */

int strip_tail(char *tail) {
	char line[LINESZ], *pos;
	int len, tlen = strlen(tail);

	for (;;) {
		if (!fgets(line, LINESZ, stdin))
			return 0;

		len = cut(line) - line;
		pos = line + len - tlen;
		if (len >= tlen && streq(pos, tail))
			*pos = '\0';

		printf("%s\n", line);
	}
}

int show_width(char *str) {
	wchar_t dest[LINESZ];

	if (setlocale(LC_ALL, "") == NULL)
		err(1, "could not initialize locale");

	if (mbstowcs(dest, str, LINESZ) < 0)
		err(1, "invalid byte sequence");

	printf("%d\n", wcswidth(dest, LINESZ));
	return 0;
}

int main(int argc, char *argv[]) {
	int i = 0;
	char *cmd = argv[++i];
	char *str;

	if (argc < 2) {
		errx(2, "missing subcommand");
	}
	else if (streq(cmd, "--help")) {
		puts("Subcommands:");
		puts("");
		puts("  next <arg>            Print stdin line that follows <arg>");
		puts("  nextw <arg>           `- same, but wrap around to 1st line");
		puts("  prev <arg>            Print stdin line that precedes <arg>");
		puts("  prevw <arg>           `- same, but wrap around to last line");
		puts("  rstrip <arg>          Strip <arg> from the end of all lines");
		puts("  width <arg>           Calculate the character-grid width of <arg>");
	}
	else if (streq(cmd, "next")) {
		if (argc < 3)
			errx(2, "missing text parameter");
		str = argv[++i];
		return next_item(str, 0);
	}
	else if (streq(cmd, "nextw")) {
		if (argc < 3)
			errx(2, "missing text parameter");
		str = argv[++i];
		return next_item(str, 1);
	}
	else if (streq(cmd, "prev")) {
		if (argc != 3)
			errx(2, "missing text parameter");
		str = argv[++i];
		return prev_item(str, 0);
	}
	else if (streq(cmd, "prevw")) {
		if (argc != 3)
			errx(2, "missing text parameter");
		str = argv[++i];
		return prev_item(str, 1);
	}
	else if (streq(cmd, "rstrip")) {
		if (argc != 3)
			errx(2, "missing text parameter");
		str = argv[++i];
		return strip_tail(str);
	}
	else if (streq(cmd, "width")) {
		if (argc != 3)
			errx(2, "missing text parameter");
		str = argv[++i];
		return show_width(str);
	}
	else {
		errx(2, "unknown subcommand '%s'", cmd);
	}
	return 0;
}
