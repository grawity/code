#include <stdio.h>

int main(void) {
	int ch, hi, n=0;

	while ((ch = getchar()) != EOF) {
		switch (ch) {
			case '0'...'9': ch -= '0'; break;
			case 'a'...'f': ch -= 'a' - 10; break;
			case 'A'...'F': ch -= 'A' - 10; break;
			default: continue;
		}

		if (n++ % 2)
			putchar(hi | ch);
		else
			hi = ch << 4;
	}

	if (n % 2) {
		putchar(hi);
		fputs("error: odd number of nibbles\n", stderr);
	}
	
	return 0;
}
