#define _GNU_SOURCE
#include "util.h"
#include <errno.h>
#include <sys/stat.h>
#include <stdlib.h>

int mkdir_p(const char *path, mode_t mode) {
	struct stat st;
	const char *p, *e;
	int r;

	e = strrchr(path, '/');
	if (!e)
		return -EINVAL;
	p = strndup(path, e - path);

	r = stat(p, &st);
	if (r == 0 && !S_ISDIR(st.st_mode))
		return -ENOTDIR;

	p = path + strspn(path, "/");
	for (;;) {
		char *t;

		e = p + strcspn(p, "/");
		p = e + strspn(e, "/");
		if (!*p)
			break;

		t = strndup(path, e - path);
		if (!t)
			return -ENOMEM;

		r = mkdir(t, mode);
		free(t);
		if (r < 0 && errno != EEXIST)
			return -errno;
	}

	r = mkdir(path, mode);
	if (r < 0 && errno != EEXIST)
		return -errno;

	return 0;
}

char * shell_escape(const char *str) {
	char *output, *ptr;

	output = malloc(strlen(str) * 2 + 3);

	ptr = output;
	*ptr++ = '"';
	while (*str) {
		switch (*str) {
		case '"':
		case '$':
		case '\\':
		case '`':
			*ptr++ = '\\';
		default:
			*ptr++ = *str++;
		}
	}
	*ptr++ = '"';
	*ptr++ = '\0';

	return output;
}
