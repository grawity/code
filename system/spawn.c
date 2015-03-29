#define _GNU_SOURCE

#include "feature.h"
#include "util.h"
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

#if defined(HAVE_NETBSD) || defined(HAVE_OPENBSD) || defined(HAVE_FREEBSD)
#  include <libgen.h>
#endif

#if defined(HAVE_SOLARIS)
#  include <fcntl.h>
#endif

char *arg0;

static void usage(void) {
	printf("Usage: %s [-cdeLPw] [-l[name]] <command> [args]\n", arg0);
	printf("\n");
	printf("  -c        close all file descriptors\n");
	printf("  -d        change working directory to $HOME\n");
	printf("  -e        unset desktop environment-specific envvars\n");
	printf("  -L        use a shared lock file instead of session\n");
	printf("  -l NAME   use given lock name instead of command name\n");
	printf("  -P        only print the lock file path\n");
	printf("  -w        fork the command and wait until it exits\n");
}

char * get_ttyname(void) {
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

void strip_slashes(char *name) {
	char *i = name;
	while (*i++)
		if (*i == '/')
			*i = '-';
}

char * get_lockfile(const char *name, int shared) {
	int r;
	char *rundir, *lockdir, *path;

	rundir = getenv("XDG_RUNTIME_DIR");
	if (!rundir) {
		fprintf(stderr, "%s: XDG_RUNTIME_DIR not set, cannot use lockfile\n",
			arg0);
		return NULL;
	}

	r = asprintf(&lockdir, "%s/lock", rundir);
	assert(r > 0);

	r = mkdir_p(lockdir, 0700);
	if (r < 0) {
		fprintf(stderr, "%s: lockdir unavailable: %s\n",
			arg0, strerror(-r));
		return NULL;
	}

	if (shared)
		r = asprintf(&path, "%s/%s.lock", lockdir, name);
	else
		r = asprintf(&path, "%s/%s.%s.lock", lockdir, name, get_ttyname());

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

void fixenv(int unset_session) {
	unsetenv("COLORTERM");
	unsetenv("GPG_TTY");
	unsetenv("SHLVL");
	unsetenv("TERM");
	unsetenv("VTE_VERSION");
	unsetenv("WINDOWID");
	unsetenv("WINDOWPATH");
	unsetenv("XTERM_LOCALE");
	unsetenv("XTERM_SHELL");
	unsetenv("XTERM_VERSION");
	if (unset_session) {
		unsetenv("DESKTOP_SESSION");
		unsetenv("GDMSESSION");
		unsetenv("GNOME_DESKTOP_SESSION_ID");
	}
}

int main(int argc, char *argv[]) {
	char **cmd = NULL;
	int do_closefd = 0;
	int do_chdir = 0;
	int do_unsetenv = 1;
	int do_wait = 0;
	int do_lock = 0;
#ifdef HAVE_FLOCK
	int do_print_lockname = 0;
	char *lockname = NULL;
	int lockshared = 0;
	char *lockfile;
	int r;
#endif
	int opt, pid;
	int lockfd = 0;

	arg0 = argv[0];

	while ((opt = getopt(argc, argv, "+cdeLl::Pw")) != -1) {
		switch (opt) {
		case 'c':
			do_closefd = 1;
			break;
		case 'd':
			do_chdir = 1;
			break;
		case 'e':
			do_unsetenv++;
			break;
#ifdef HAVE_FLOCK
		case 'L':
			do_lock = 1;
			lockshared = 1;
			break;
		case 'l':
			do_lock = 1;
			if (!optarg || !strcmp(optarg, "-"))
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
			usage();
			return 2;
		}
	}

	if (optind >= argc) {
		fprintf(stderr, "%s: must specify a command to run\n", arg0);
		return 2;
	} else {
		cmd = &argv[optind];
	}

#ifdef HAVE_FLOCK
	if (do_lock) {
		char *env;

		if (!lockname || !*lockname)
			lockname = basename(cmd[0]);

		strip_slashes(lockname);

		lockfile = get_lockfile(lockname, lockshared);
		if (do_print_lockname) {
			printf("%s\n", lockfile);
			return 0;
		}

		lockfd = open(lockfile, O_RDWR|O_CREAT, 0600);
		if (lockfd < 0) {
			fprintf(stderr, "%s: cannot open lockfile '%s': %m\n",
				arg0, lockfile);
			return 1;
		}

		if (flock(lockfd, LOCK_EX|LOCK_NB) < 0) {
			if (errno == EWOULDBLOCK)
				fprintf(stderr, "%s: already running\n", cmd[0]);
			else
				fprintf(stderr, "%s: could not lock '%s': %m\n",
					arg0, lockname);
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
		fixenv(do_unsetenv - 1);
		if (setsid() < 0) {
			fprintf(stderr, "%s: detaching from session failed: %m\n",
				arg0);
			return 1;
		}
		if (do_closefd) {
			if (!closefds())
				return 1;
		}
		if (execvp(cmd[0], cmd) < 0) {
			fprintf(stderr, "%s: failed to execute '%s': %m\n",
				arg0, cmd[0]);
			return 1;
		}
		return 0;
	case -1:
		fprintf(stderr, "%s: fork failed: %m\n", arg0);
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
