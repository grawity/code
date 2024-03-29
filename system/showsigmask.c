#define _GNU_SOURCE
#include "config.h"
#include <err.h>
#include <signal.h> /* NSIG */
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h> /* getopt */

#if !defined(HAVE_SIGABBREV_NP)
extern const char *const sys_sigabbrev[NSIG];
#define sigabbrev_np(sig) sys_sigabbrev[sig]
#endif

const char * strsigabbrev(int sig) {
	static char rt_sigabbrev[NSIG][12];

	if (sigabbrev_np(sig))
		return sigabbrev_np(sig);
	else if (sig == SIGRTMIN)
		return "RTMIN";
	else if (sig == SIGRTMAX)
		return "RTMAX";
	else if (sig > SIGRTMIN && sig < SIGRTMAX) {
		if (!*rt_sigabbrev[sig])
			snprintf(rt_sigabbrev[sig], 12, "RTMIN+%d", sig - SIGRTMIN);
		return rt_sigabbrev[sig];
	} else
		return "-";
}

void printmask(char *label, char *hexstrmask) {
	unsigned i, sig;
	unsigned long long arg, bit;

	arg = strtoul(hexstrmask, NULL, 16);

	printf("%s: %016llx\n\n", label, arg);

	if (!arg)
		printf("  (no signal bits set)\n");

	for (i=0; i<64; i++) {
		sig = i + 1;
		bit = 1ULL << i;

		if (arg & bit)
			printf("  [%16llx]  %3u | %-8s | %s\n",
				bit, sig, strsigabbrev(sig), strsignal(sig));
	}

	printf("\n");
}

void printpidmasks(int pid) {
	char *path = "/proc/self/status";
	char *k, *v;
	FILE *fp;

	if (pid >= 0) {
		printf("showing signal masks for PID %d\n", pid);
		asprintf(&path, "/proc/%d/status", pid);
	} else {
		printf("showing signal masks for current process (PID %d)\n", getpid());
	}
	printf("\n");

	fp = fopen(path, "r");
	if (!fp)
		err(1, "could not open '%s'", path);

	while (fscanf(fp, "%m[^:]: %m[^\n]\n", &k, &v) > 0) {
		if (!strcmp(k, "SigBlk"))
			printmask("blocked", v);
		else if (!strcmp(k, "SigIgn"))
			printmask("ignored", v);
		else if (!strcmp(k, "SigCgt"))
			printmask("caught", v);

		free(k);
		free(v);
	}

	fclose(fp);
}

static void usage() {
	printf("Usage: %s [-a MASK] [-p PID]\n", "showsigmask");
	printf("\n");
	printf("Options:\n");
	//      |-------|-------|-------|
	printf("  -a MASK        interpret given mask value (in hexadecimal)\n");
	printf("  -p PID         show signal masks for given process\n");
	printf("\n");
	printf("If neither -a nor -p specified, will show its own signal mask values.\n");
}

int main(int argc, char *argv[]) {
	int opt, pid = -1;
	char *arg = NULL;

	while ((opt = getopt(argc, argv, "a:p:")) != -1) {
		switch (opt) {
		case 'a':
			if (pid != -1 || arg)
				errx(2, "-a or -p already specified");
			arg = optarg;
			break;
		case 'p':
			if (pid != -1 || arg)
				errx(2, "-a or -p already specified");
			pid = atoi(optarg);
			break;
		default:
			usage();
			return 2;
		}
	}

	argc -= optind-1;
	argv += optind-1;

	if (argc > 1)
		errx(2, "too many arguments");
	else if (arg)
		printmask("arg", arg);
	else
		printpidmasks(pid);

	return 0;
}
