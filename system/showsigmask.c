#include <stdio.h>
#include <string.h>
#include <stdlib.h>

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
			printf("  %3u [%16llx]: %s\n", sig, bit, strsignal(sig));
	}

	printf("\n");
}

int main(int argc, char *argv[]) {
	FILE *fp;
	char *k, *v;

	if (argc > 1) {
		int i = 0;
		while (argv[++i])
			prsigs("arg", argv[i]);
		return 0;
	}

	fp = fopen("/proc/self/status", "r");

	while (fscanf(fp, "%m[^:]: %m[^\n]\n", &k, &v) > 0) {
		if (!strcmp(k, "SigBlk")) prsigs("blocked", v);
		else if (!strcmp(k, "SigIgn")) prsigs("ignored", v);
		else if (!strcmp(k, "SigCgt")) prsigs("caught", v);

		free(k);
		free(v);
	}

	fclose(fp);
	return 0;
}
