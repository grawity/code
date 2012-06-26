#include <stdio.h>
#include <unistd.h>

int main(int argc, char *argv[]) {
	if (freopen("/dev/null", "w", stderr) == NULL)
		perror("freopen");
	return execv("/bin/cat", argv);
}
