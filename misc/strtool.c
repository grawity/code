#include <stdio.h>
#include <string.h>

#define LINESZ 512

static inline int streq(const char *a, const char *b) {
	return strcmp(a, b) == 0;
}

static char * cut(char *line) {
	char *c;
	for (c = line; *c; c++) {
		if (*c == '\n') {
			*c = '\0';
			return c;
		}
	}
	return c;
}

/*
 * print line after first match
 */

int next_item(char *want, int loop) {
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
		} else if (!strcmp(line[n], want))
			found = 1;
	}
	if (!found || !loop || !n)
		return 1;
	else {
		printf("%s\n", line[0]);
		return 0;
	}
}

/*
 * print line before first match
 */

int prev_item(char *want, int loop) {
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
			} else
				break;
		}
	}
	if (count || !loop)
		return 1;
	else {
		while (fgets(line[n], LINESZ, stdin))
			;
		cut(line[n]);
		printf("%s\n", line[n]);
		return 0;
	}
}

/*
 * remove text from end of the line
 */

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

int main(int argc, char *argv[]) {
	int i = 0;
	char *cmd = argv[++i];

	if (argc < 2) {
		fprintf(stderr, "Missing function\n");
		return 2;
	}
	else if (streq(cmd, "next")) {
		if (argc < 3)
			return 2;
		char *str = argv[++i];
		return next_item(str, 0);
	}
	else if (streq(cmd, "nextl")) {
		if (argc < 3)
			return 2;
		char *str = argv[++i];
		return next_item(str, 1);
	}
	else if (streq(cmd, "prev")) {
		if (argc != 3)
			return 2;
		char *str = argv[++i];
		return prev_item(str, 0);
	}
	else if (streq(cmd, "prevl")) {
		if (argc != 3)
			return 2;
		char *str = argv[++i];
		return prev_item(str, 1);
	}
	else if (streq(cmd, "rstrip")) {
		if (argc != 3)
			return 2;
		char *str = argv[++i];
		return strip_tail(str);
	}
	else {
		fprintf(stderr, "Unknown function '%s'\n", cmd);
		return 2;
	}
}
