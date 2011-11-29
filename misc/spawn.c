#define _GNU_SOURCE
#include <errno.h>
#include <getopt.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/file.h>
#include <sys/wait.h>
#include <unistd.h>

char *arg0;

static void usage() {
	fprintf(stderr, "usage: %s [-L] [-l name] [-w] <command> [args]\n", arg0);
	exit(2);
}

char * get_ttyname() {
	char *d, *i;
	if ((d = getenv("DISPLAY"))) {
		*rindex(d, '.') = 0;
		return d;
	}
	if ((d = ttyname(2))) {
		i = d;
		while (*i++)
			if (*i == '/')
				*i = '-';
		return d + 5;
	}
	return "batch";
}

char * get_lockfile(char *name, int shared) {
	char *dir = getenv("XDG_RUNTIME_DIR");
	if (dir == NULL) {
		fprintf(stderr, "%s: XDG_RUNTIME_DIR not set, cannot use lockfile\n", arg0);
		exit(3);
	}
	char *disp;
	if (shared)
		disp = "shared";
	else
		disp = get_ttyname();
	char *path;
	asprintf(&path, "%s/%s.%s.lock", dir, name, disp);
	return path;
}

int main(int argc, char *argv[]) {
	char **cmd;
	int do_wait = 0;
	int do_lock = 0;
	char *lockname = NULL;
	int lockshared = 0;
	char *lockfile;
	int opt;
	int lockfd;

	arg0 = argv[0];

	while ((opt = getopt(argc, argv, "+Ll:w")) != -1) {
		switch (opt) {
		case 'L':
			lockshared = 1;
			break;
		case 'l':
			do_lock = 1;
			if (!strcmp(optarg, "-"))
				lockname = NULL;
			else
				lockname = optarg;
			break;
		case 'w':
			do_wait = 1;
			break;
		default:
			usage();
		}
	}

	if (optind >= argc) {
		fprintf(stderr, "%s: must specify a command to run\n", arg0);
		usage();
	} else {
		cmd = &argv[optind];
	}

	if (do_lock) {
		if (!lockname)
			lockname = cmd[0];
		lockfile = get_lockfile(lockname, lockshared);
		if ((lockfd = open(lockfile, O_RDONLY|O_CREAT, 0600)) < 0) {
			perror("open(lockfile)");
			return 1;
		}
		if (flock(lockfd, LOCK_EX|LOCK_NB) < 0) {
			if (errno == EWOULDBLOCK)
				fprintf(stderr, "%s: already running\n", cmd[0]);
			else
				perror("flock");
			return 1;
		}
		char *env;
		asprintf(&env, "SPAWN_LOCKFD=%d", lockfd);
		putenv(env);
	}

	switch (fork()) {
	case 0:
		if (setsid() < 0) {
			perror("setsid");
			return 1;
		}
		if (execvp(cmd[0], cmd) < 0) {
			fprintf(stderr, "%s: failed to execute '%s': %m\n", arg0, cmd[0]);
			return 1;
		}
		return 0;
	case -1:
		perror("fork");
		return 1;
	default:
		if (do_wait)
			wait(NULL);
		return 0;
	}
}
