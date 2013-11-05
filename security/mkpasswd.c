#define _XOPEN_SOURCE 500

#include <errno.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>
#include <string.h>

char base64[] = "abcdefghijklmnopqrstuvwxyz"
		"ABCDEFGHIJKLMNOPQRSTUVWXYZ"
		"0123456789./";

char *makesalt(char algo) {
	char buf[12], salt[20];
	unsigned i=0, j=0, fd;

	fd = open("/dev/urandom", O_RDONLY);
	read(fd, buf, 12);
	close(fd);

	salt[j++] = '$';
	salt[j++] = algo;
	salt[j++] = '$';
	while (i < sizeof(buf)) {
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

int main(int argc, char *argv[]) {
	char *salt = NULL, *passwd = NULL;
	char *hash;
	int c;

	while ((c = getopt(argc, argv, "p:s:")) != -1) {
		switch (c) {
		case 'p':
			passwd = optarg;
			break;
		case 's':
			salt = optarg;
			break;
		}
	}

	if (!salt)
		salt = makesalt('5');
	if (!passwd)
		passwd = getpass("Password: ");

	hash = crypt(passwd, salt);

	if (hash)
		printf("%s\n", hash);
	else if (errno == EINVAL)
		fprintf(stderr, "%s: Invalid salt or hash algorithm\n", argv[0]);
	else
		perror(argv[0]);

	return !hash;
}
