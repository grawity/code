/*
 * Based on sulogin from util-linux
 *
 * Copyright (C) 1998-2003 Miquel van Smoorenburg.
 * Copyright (C) 2012 Karel Zak <kzak@redhat.com>
 * Copyright (C) 2012 Werner Fink <werner@suse.de>
 * Copyright (C) 2013 Mantas Mikulėnas <grawity@gmail.com>
 *
 * Released under GPLv2
 */

#define _PATH_PASSWD		"/etc/passwd"
#define _PATH_SHADOW_PASSWD	"/etc/shadow"

#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>
#include <signal.h>
#include <pwd.h>
#include <shadow.h>
#include <termios.h>
#include <getopt.h>
#include <sys/ioctl.h>
#include <crypt.h>
#include <err.h>
#include <limits.h>
#include <locale.h>
#include <stdbool.h>
#include <errno.h>

#ifdef HAVE_LIBSELINUX
# include <selinux/selinux.h>
# include <selinux/get_context_list.h>
#endif

#include "kzak_ttyutils.h"

#include "util.h"

struct sigaction saved_sigint;
struct sigaction saved_sigtstp;
struct sigaction saved_sigquit;

struct {
	bool debug;
	char *loader;
	char *shell;
} opts;

static void mask_signal(int signal, void (*handler)(int),
		struct sigaction *origaction)
{
	struct sigaction newaction;

	newaction.sa_handler = handler;
	sigemptyset(&newaction.sa_mask);
	newaction.sa_flags = 0;

	sigaction(signal, NULL, origaction);
	sigaction(signal, &newaction, NULL);
}

static void unmask_signal(int signal, struct sigaction *sa)
{
	sigaction(signal, sa, NULL);
}

static bool valid(const char *pass)
{
	const char *s;
	char id[5];
	size_t len;
	off_t off;

	if (!pass[0])
		return true;

	if (pass[0] != '$')
		goto check_des;

	/*
	 * up to 4 bytes for the signature e.g. $1$
	 */
	for (s = pass+1; *s && *s != '$'; s++);

	if (*s++ != '$')
		return false;

	if ((off = (off_t)(s-pass)) > 4 || off < 3)
		return 0;

	memset(id, '\0', sizeof(id));
	strncpy(id, pass, off);

	/*
	 * up to 32 bytes for the salt
	 */
	for (; *s && *s != '$'; s++);

	if (*s++ != '$')
		return false;

	if ((off_t)(s-pass) > 32)
		return false;

	len = strlen(s);

	if ((strcmp(id, "$1$") == 0) && (len < 22 || len > 24))
		return false;
	if ((strcmp(id, "$5$") == 0) && (len < 42 || len > 44))
		return false;
	if ((strcmp(id, "$6$") == 0) && (len < 85 || len > 87))
		return false;

	return true;

check_des:
	if (strlen(pass) != 13)
		return false;

	for (s = pass; *s; s++) {
		if ((*s < '0' || *s > '9') &&
		    (*s < 'a' || *s > 'z') &&
		    (*s < 'A' || *s > 'Z') &&
		    *s != '.' && *s != '/')
			return false;
	}
	return true;
}

static inline void set(char **var, char *val)
{
	if (val)
		*var = val;
}

static struct passwd *getrootpwent(void)
{
	static struct passwd pwent;
	FILE *fp;
	static char line[256];
	static char sline[256];
	char *p;

	pwent.pw_name   = "root";
	pwent.pw_passwd = "";
	pwent.pw_uid    = 0;
	pwent.pw_gid    = 0;
	pwent.pw_gecos  = "Super User";
	pwent.pw_dir    = "/";
	pwent.pw_shell  = "";

	if ((fp = fopen(_PATH_PASSWD, "r")) == NULL) {
		warn("cannot open %s", _PATH_PASSWD);
		return &pwent;
	}
	while ((p = fgets(line, 256, fp)) != NULL) {
		if (strncmp(line, "root:", 5) != 0)
			continue;
		p += 5;
		set(&pwent.pw_passwd, strsep(&p, ":"));
		strsep(&p, ":");
		strsep(&p, ":");
		set(&pwent.pw_gecos,  strsep(&p, ":"));
		set(&pwent.pw_dir,    strsep(&p, ":"));
		set(&pwent.pw_shell,  strsep(&p, "\n"));
		p = line;
		break;
	}
	fclose(fp);

	if (p == NULL) {
		warnx("%s: no entry for root", _PATH_PASSWD);
		return &pwent;
	}
	if (valid(pwent.pw_passwd))
		return &pwent;

	strcpy(pwent.pw_passwd, "");

	if ((fp = fopen(_PATH_SHADOW_PASSWD, "r")) == NULL) {
		warn("cannot open %s", _PATH_PASSWD);
		return &pwent;
	}
	while ((p = fgets(sline, 256, fp)) != NULL) {
		if (strncmp(sline, "root:", 5) != 0)
			continue;
		p += 5;
		set(&pwent.pw_passwd, strsep(&p, ":"));
		break;
	}
	fclose(fp);

	if (p == NULL) {
		warnx("%s: no entry for root", _PATH_SHADOW_PASSWD);
		strcpy(pwent.pw_passwd, "");
	}
	if (!valid(pwent.pw_passwd)) {
		warnx("%s: root password garbled", _PATH_SHADOW_PASSWD);
		strcpy(pwent.pw_passwd, "");
	}
	return &pwent;
}

static char *getpasswd(void)
{
	struct termios old, tty;
	static char pass[128];
	char *ret = pass;
	size_t i;

	printf("\e[37;41m%s:\e[m ", "root password");
	fflush(stdout);

	tcgetattr(0, &old);
	tcgetattr(0, &tty);
	tty.c_iflag &= ~(IUCLC|IXON|IXOFF|IXANY);
	tty.c_lflag &= ~(ECHO|ECHOE|ECHOK|ECHONL|TOSTOP);
	tcsetattr(0, TCSANOW, &tty);

	pass[sizeof(pass) - 1] = 0;

	if (read(0, pass, sizeof(pass) - 1) <= 0)
		ret = NULL;
	else {
		for (i = 0; i < sizeof(pass) && pass[i]; i++)
			if (pass[i] == '\r' || pass[i] == '\n') {
				pass[i] = 0;
				break;
			}
	}
	tcsetattr(0, TCSANOW, &old);
	printf("\n");

	return ret;
}

static bool authenticate(struct passwd *pwent)
{
	char *p;

	if (!pwent->pw_passwd[0]) {
		warnx("skipping password check");
		return true;
	}

	p = getpasswd();
	if (!p)
		return false;
	if (!pwent->pw_passwd[0])
		return true;

	return streq(crypt(p, pwent->pw_passwd), pwent->pw_passwd);
}

static void try_shell(const char *shell, const char *loader)
{
	setenv("SHELL", shell, 1);

	if (loader)
		execl(loader, loader, shell, NULL);
	else
		execl(shell, shell, NULL);

	if (errno == ENOENT && access(shell, X_OK) == 0) {
		warnx("%s: exec failed due to missing interpreter", shell);
		if (!loader)
			warnx("use option -L to specify a working ld-linux.so");
	}
	else
		warn("%s: exec failed", shell);
}

static void sushell(struct passwd *pwent)
{
	char home[PATH_MAX];
	char *p;
	char *shell;
	char *loader;

	if (pwent && chdir(pwent->pw_dir) != 0) {
		warn("could not change directory to %s", pwent->pw_dir);
		warnx("using \"/\" as home directory instead");
		if (chdir("/") != 0)
			warn("could not change directory to system root");
	} else {
		if (chdir("/") != 0)
			warn("could not change directory to system root");
	}

	if ((p = getenv("SUSHELL")))
		shell = p;
	else if (opts.shell)
		shell = opts.shell;
	else if (pwent && *pwent->pw_shell)
		shell = pwent->pw_shell;
	else
		shell = "/bin/sh";

	if ((p = getenv("LDPATH")))
		loader = p;
	else
		loader = opts.loader;

	if (getcwd(home, sizeof(home)))
		setenv("HOME", home, 1);

	setenv("LOGNAME", "root", 1);
	setenv("USER", "root", 1);
	setenv("SHLVL", "0", 1);

	unmask_signal(SIGINT, &saved_sigint);
	unmask_signal(SIGTSTP, &saved_sigtstp);
	unmask_signal(SIGQUIT, &saved_sigquit);

#ifdef HAVE_LIBSELINUX
	if (is_selinux_enabled() > 0) {
		security_context_t scon = NULL;
		char *seuser = NULL;
		char *level = NULL;
		if (getseuserbyname("root", &seuser, &level) == 0) {
			if (get_default_context_with_level(seuser, level, 0, &scon) == 0) {
				if (setexeccon(scon) != 0)
					warnx("setexeccon failed");
				freecon(scon);
			}
		}
		free(seuser);
		free(level);
	}
#endif

	try_shell(shell, loader);
	try_shell("/bin/sh", loader);
}

static void fixtty(void)
{
	struct termios tp;
	int x = 0, fl = 0;

	/* Skip serial console */
	if (ioctl(STDIN_FILENO, TIOCMGET, (char *) &x) == 0)
		return;

#if defined(IUTF8) && defined(KDGKBMODE)
	/* Detect mode of current keyboard setup, e.g. for UTF-8 */
	if (ioctl(STDIN_FILENO, KDGKBMODE, &x) == 0 && x == K_UNICODE) {
		setlocale(LC_CTYPE, "C.UTF-8");
		fl |= UL_TTY_UTF8;
	}
#else
	setlocale(LC_CTYPE, "POSIX");
#endif
	memset(&tp, 0, sizeof(struct termios));
	if (tcgetattr(STDIN_FILENO, &tp) < 0) {
		warn("tcgetattr failed");
		return;
	}

	reset_virtual_console(&tp, fl);

	if (tcsetattr(STDIN_FILENO, TCSADRAIN, &tp))
		warn("tcsetattr failed");
}

static void usage()
{
	puts("Usage: sulogin [-L ld-path] [-S shell]");
	puts("");
	puts("  -L ld-path    specify a loader (ld-linux) to explicitly run");
	puts("  -S shell      specify a shell to run instead of /bin/sh");
}

int main(int argc, char *argv[])
{
	int opt;
	int tries = 1;
	struct passwd *pwent;

	setlocale(LC_ALL, "");

	if (getenv("DEBUG"))
		opts.debug = true;

	while ((opt = getopt(argc, argv, "L:S:")) != -1) {
		switch (opt) {
		case 'L':
			opts.loader = optarg;
			break;
		case 'S':
			opts.shell = optarg;
			break;
		default:
			usage();
			exit(EXIT_FAILURE);
		}
	}

	/* make sure we're either setuid root, or have CAP_SET{UID,GID} */

	if (opts.debug)
		fprintf(stderr, "; current uid=%d euid=%d\n", getuid(), geteuid());

	if (setreuid(0, 0) != 0)
		err(EXIT_FAILURE, "cannot obtain root privileges (setreuid)");

	if (setregid(0, 0) != 0)
		err(EXIT_FAILURE, "cannot change primary group to 'root'");

	if (getpid() == 1) {
		setsid();
		if (ioctl(STDIN_FILENO, TIOCSCTTY, (char *)1))
			warn("TIOCSCTTY: ioctl failed");
	}

	fixtty();

	pwent = getrootpwent();

	if (!pwent)
		warnx("cannot open password database");

	while (pwent && tries--) {
		mask_signal(SIGQUIT, SIG_IGN, &saved_sigquit);
		mask_signal(SIGTSTP, SIG_IGN, &saved_sigtstp);
		mask_signal(SIGINT,  SIG_IGN, &saved_sigint);
		if (authenticate(pwent))
			break;
		warnx("login incorrect");
	}

	if (tries >= 0) {
		sushell(pwent);
		warnx("unable to run any shell, you're screwed");
	}

	return EXIT_FAILURE;
}
