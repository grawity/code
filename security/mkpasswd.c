#define _XOPEN_SOURCE 500

#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>
#include <string.h>

static char base64[] = "abcdefghijklmnopqrstuvwxyz"
			"ABCDEFGHIJKLMNOPQRSTUVWXYZ"
			"0123456789./";

char *makesalt(char algo) {
	char buf[12], salt[20];
	int i=0, j=0, fd;

	fd = open("/dev/urandom", O_RDONLY);
	read(fd, buf, 12);
	close(fd);

	salt[j++] = '$';
	salt[j++] = algo;
	salt[j++] = '$';
	while (i<sizeof(buf)) {
		char a = i < sizeof(buf) ? buf[i++] : 0;
		char b = i < sizeof(buf) ? buf[i++] : 0;
		char c = i < sizeof(buf) ? buf[i++] : 0;
		long triple = (a << 020) + (b << 010) + c;
		salt[j++] = base64[(triple >> 3*6) & 077];
		salt[j++] = base64[(triple >> 2*6) & 077];
		salt[j++] = base64[(triple >> 1*6) & 077];
		salt[j++] = base64[(triple >> 0*6) & 077];
	}
	salt[j++] = '$';
	salt[j++] = 0;

	return strdup(salt);
}

int main(void) {
	char *salt, *passwd, *hash;
	char algo = '5';

	salt = makesalt(algo);
	passwd = getpass("Password: ");
	hash = crypt(passwd, salt);
	printf("%s\n", hash);
	return 0;
}
