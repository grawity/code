#include <stdio.h>
#include <unistd.h>

int main(int argc, char *argv[]) {
	freopen("/dev/null", "w", stderr);
	return execv("/bin/cat", argv);
}
