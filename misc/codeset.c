#include <stdio.h>
#include <stdlib.h>
#include <locale.h>
#include <langinfo.h>

int main(int argc, char *argv[]) {
	while (*++argv)
		putenv(*argv);

	setlocale(LC_ALL, "");

	printf("%s\n", nl_langinfo(CODESET));

	return 0;
}
