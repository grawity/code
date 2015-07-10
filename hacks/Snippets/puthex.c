
#include <stdio.h>

char hex[] = "0123456789abcdef";

typedef unsigned long long u64;

void puthex(char *buf, u64 value) {
	int n = sizeof(value)*2;
	buf += n;
	*buf-- = 0;
	while (n--) {
		*buf-- = hex[value & 0xF];
		value >>= 4;
	}
}


int main() {
	char buf[100] = "!----____----____@";
	puthex(buf+1, 0x1234abcd5678abcd);
	printf("%s\n", buf);
}
