#define _GNU_SOURCE
#include <errno.h>
#include <getopt.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/file.h>
#include <sys/wait.h>
#include <dirent.h>
#include <unistd.h>
#include <assert.h>

/* Todo: move to a header */

#define HAVE_FLOCK

#ifdef HAVE_SOLARIS
#  undef HAVE_FLOCK
#endif

char *arg0;

static int usage() {
	fprintf(stderr, "usage: %s [-L] [-l name] [-w] <command> [args]\n", arg0);
	return 2;
}

char * get_ttyname() {
	char *d, *i;
	if ((d = getenv("DISPLAY"))) {
		if ((i = strrchr(d, '.')))
			*i = 0;
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
	int r;
	char *dir, *disp, *path;

	dir = getenv("XDG_RUNTIME_DIR");
	if (dir == NULL) {
		fprintf(stderr, "%s: XDG_RUNTIME_DIR not set, cannot use lockfile\n", arg0);
		exit(3);
	}

	if (shared)
		disp = "shared";
	else
		disp = get_ttyname();

	r = asprintf(&path, "%s/%s.%s.lock", dir, name, disp);
	assert(r > 0);
	return path;
}

int chdir_home(void) {
	int r;
	char *dir;

	dir = getenv("HOME");
	if (!dir)
		goto fallback;

	r = chdir(dir);
	if (r == 0)
		return 1;
	else
		fprintf(stderr, "%s: failed to chdir to '%s': %m\n", arg0, dir);

fallback:
	r = chdir("/");
	if (r == 0)
		return 1;
	else
		fprintf(stderr, "%s: failed to chdir to '/': %m\n", arg0);

	return 0;
}

int closefds(void) {
	DIR *dirp;
	struct dirent *ent;
	int fd;

	dirp = opendir("/dev/fd");
	if (!dirp) {
		fprintf(stderr, "%s: failed to open /dev/fd: %m\n", arg0);
		return 0;
	}

	while ((ent = readdir(dirp))) {
		if (ent->d_name[0] == '.')
			continue;
		fd = atoi(ent->d_name);
		if (fd != dirfd(dirp))
			close(fd);
	}

	closedir(dirp);

	fd = open("/dev/null", O_RDWR);
	if (fd < 0) {
		fprintf(stderr, "%s: failed to open /dev/null: %m\n", arg0);
		return 0;
	}

	dup2(fd, 0);
	dup2(fd, 1);
	dup2(fd, 2);

	if (fd != 0)
		close(fd);

	return 1;
}

int main(int argc, char *argv[]) {
	char **cmd = NULL;
	int do_closefd = 0;
	int do_chdir = 0;
	int do_wait = 0;
	int do_lock = 0;
	int do_print_lockname = 0;
	char *lockname = NULL;
	int lockshared = 0;
	char *lockfile;
	int opt;
	int lockfd = 0;
	int pid;
	int r;

	arg0 = argv[0];

	while ((opt = getopt(argc, argv, "+cdLl:Pw")) != -1) {
		switch (opt) {
		case 'c':
			do_closefd = 1;
			break;
		case 'd':
			do_chdir = 1;
			break;
#ifdef HAVE_FLOCK
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
		case 'P':
			do_lock = 1;
			do_print_lockname = 1;
			break;
#else
		case 'L':
		case 'l':
		case 'P':
			fprintf(stderr, "flock() support missing\n");
			return 42;
#endif
		case 'w':
			do_wait = 1;
			break;
		default:
			return usage();
		}
	}

	if (optind >= argc) {
		fprintf(stderr, "%s: must specify a command to run\n", arg0);
		return usage();
	} else {
		cmd = &argv[optind];
	}

#ifdef HAVE_FLOCK
	if (do_lock) {
		char *env;

		if (!lockname)
			lockname = cmd[0];
		lockfile = get_lockfile(lockname, lockshared);
		if (do_print_lockname) {
			printf("%s\n", lockfile);
			return 0;
		}

		lockfd = open(lockfile, O_RDWR|O_CREAT, 0600);
		if (lockfd < 0) {
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

		r = asprintf(&env, "SPAWN_LOCKFD=%d", lockfd);
		assert(r > 0);
		putenv(env);
	}
#endif

	if (do_chdir) {
		if (!chdir_home())
			return 1;
	}

	pid = fork();
	switch (pid) {
	case 0:
		if (setsid() < 0) {
			perror("setsid");
			return 1;
		}
		if (do_closefd) {
			if (!closefds())
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
		if (do_lock && lockfd) {
			char *str = NULL;
			int len = asprintf(&str, "%d\n", pid);
			if (str) {
				len -= write(lockfd, str, len);
				free(str);
			}
		}
		if (do_wait)
			wait(NULL);
		return 0;
	}
}
