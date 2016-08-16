#define _GNU_SOURCE
#include <err.h>
#include <signal.h> /* NSIG */
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h> /* getopt */

extern const char *const sys_sigabbrev[NSIG];

const char * strsigabbrev(int sig) {
	static char rt_sigabbrev[NSIG][12];

	if (sys_sigabbrev[sig])
		return sys_sigabbrev[sig];
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

void prsigs(char *k, char *v) {
	unsigned i, sig;
	unsigned long long arg, bit;

	arg = strtoul(v, NULL, 16);

	printf("%s: %016llx\n\n", k, arg);

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

int main(int argc, char *argv[]) {
	FILE *fp;
	char *path = "/proc/self/status";
	char *k, *v;
	int opt, pid = -1;

	while ((opt = getopt(argc, argv, "p:")) != -1) {
		switch (opt) {
		case 'p':
			if (pid != -1)
				errx(2, "PID already specified");
			pid = atoi(optarg);
			break;
		default:
			errx(2, "bad usage");
		}
	}

	argc -= optind;
	argv += optind;

	if (argc > 1) {
		int i = 0;
		while (argv[++i])
			prsigs("arg", argv[i]);
		return 0;
	}

	if (pid > 0)
		asprintf(&path, "/proc/%d/status", pid);
	fp = fopen(path, "r");
	if (!fp)
		err(1, "could not open '%s'", path);

	while (fscanf(fp, "%m[^:]: %m[^\n]\n", &k, &v) > 0) {
		if (!strcmp(k, "SigBlk"))
			prsigs("blocked", v);
		else if (!strcmp(k, "SigIgn"))
			prsigs("ignored", v);
		else if (!strcmp(k, "SigCgt"))
			prsigs("caught", v);

		free(k);
		free(v);
	}

	fclose(fp);
	return 0;
}
