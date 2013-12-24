#include <stdio.h>
#include <string.h>
#include <stdlib.h>

void prsigs(char *k, char *v) {
	unsigned i;
	unsigned long long sp;

	sp = strtoul(v, NULL, 16);

	printf("%s: %016llx\n\n", k, sp);

	if (!sp)
		printf("  (no signal bits set)\n");

	for (i=0; i<64; i++) {
		if (sp & 1LL << i)
			printf("  %3u [%16llx]: %s\n", i+1, 1LL << i, strsignal(i+1));
	}

	printf("\n");
}

int main(int argc, char *argv[]) {
	FILE *fp;
	char *k, *v;

	if (argc > 1) {
		prsigs("arg", argv[1]);
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
