#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <locale.h>
#include <langinfo.h>

int main(int argc, char *argv[]) {
	int opt;
	nl_item do_langinfo = CODESET;

	while ((opt = getopt(argc, argv, "D")) != -1) {
		switch (opt) {
		case 'D':
			do_langinfo = _DATE_FMT;
			break;
		case '?':
			return 2;
		}
	}

	while (*++argv)
		putenv(*argv);

	setlocale(LC_ALL, "");

	printf("%s\n", nl_langinfo(do_langinfo));

	return 0;
}
