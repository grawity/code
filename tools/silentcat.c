#include <stdio.h>
#include <unistd.h>

int main(int argc, char *argv[]) {
	/* close stderr */
	freopen("/dev/null", "w", stderr);

	/* exec real cat */
	argv[0] = "cat";
	return execvp(argv[0], argv);
}
