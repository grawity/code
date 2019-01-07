#define _GNU_SOURCE
#define _XOPEN_SOURCE 500

#include <errno.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>
#include <string.h>

char base64[] = "abcdefghijklmnopqrstuvwxyz"
		"ABCDEFGHIJKLMNOPQRSTUVWXYZ"
		"0123456789./";

#define RAND_DEV "/dev/urandom"

int randsalt(void *buf, ssize_t len) {
	int fd, n;

	fd = open(RAND_DEV, O_RDONLY);
	if (fd < 0) {
		fprintf(stderr, "mkpasswd: %s: %m\n", RAND_DEV);
		return 0;
	}

	n = read(fd, buf, len);
	if (n < len) {
		fprintf(stderr, "mkpasswd: %s: short read (%m)\n", RAND_DEV);
		close(fd);
		return 0;
	}

	close(fd);
	return 1;
}

char *makesalt(char algo) {
	char buf[12], salt[20+1];
	unsigned i=0, j=0;

	if (!randsalt(buf, sizeof(buf)))
		return NULL;

	salt[j++] = '$';
	salt[j++] = algo;
	salt[j++] = '$';
	while (i < sizeof(buf)) {
		unsigned char a, b, c;
		unsigned triple;

		a = i < sizeof(buf) ? buf[i++] : 0;
		b = i < sizeof(buf) ? buf[i++] : 0;
		c = i < sizeof(buf) ? buf[i++] : 0;
		triple = (a << 020) | (b << 010) | c;
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
	if (!salt)
		return 1;

	if (!passwd)
		passwd = getpass("Password: ");
	if (!passwd)
		return 1;

	hash = crypt(passwd, salt);

	if (hash)
		printf("%s\n", hash);
	else if (errno == EINVAL)
		fprintf(stderr, "%s: Invalid salt or hash algorithm\n", argv[0]);
	else
		perror(argv[0]);

	return !hash;
}
