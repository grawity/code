#define _GNU_SOURCE
#include <sys/types.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <pwd.h>
#include <grp.h>
#include <errno.h>

static int split_user_spec(char arg[], char *u[], char *g[]) {
	*u = *g = NULL;
	if (sscanf(arg, "%a[^:]:%as", u, g) == 2)
		return 1;
	else if (sscanf(arg, ":%as", g) == 1)
		return 1;
	else if (sscanf(arg, "%a[^:]", u) == 1)
		return 1;
	else
		return 0;
}

static int parse_user_spec(char arg[], char *u[], uid_t *uid, char *g[], gid_t *gid) {
	struct passwd *pw;
	struct group *gr;

	if (!split_user_spec(arg, u, g))
		return 0;

	if (*u != NULL) {
		pw = getpwnam(*u);
		if (pw == NULL)
			return 0;
		*uid = pw->pw_uid;
	} else {
		return 0;
	}

	if (*g != NULL) {
		gr = getgrnam(*g);
		if (gr == NULL)
			return 0;
		*gid = gr->gr_gid;
	} else {
		*gid = pw->pw_gid;
	}

	return 1;
}

int main(int argc, char *argv[]) {
	char *u;
	char *g;
	uid_t uid;
	gid_t gid;

	char *spec = argv[1];

	if (!parse_user_spec(spec, &u, &uid, &g, &gid)) {
		fprintf(stderr, "setuid: invalid user %s\n", spec);
		return 1;
	}

	if (initgroups(u, gid) < 0) {
		perror("initgroups");
		return 1;
	}

	if (setgid(gid) < 0) {
		perror("setgid");
		return 1;
	}

	if (setuid(uid) < 0) {
		perror("setuid");
		return 1;
	}

	execlp("id", "id", NULL);

	return 0;
}
