#include <stdio.h>
#include <sys/ioctl.h>

int main(void) {
	struct winsize argp;
	int fd = 0;
	int r = ioctl(fd, TIOCGWINSZ, &argp);
	if (r < 0) {
		perror("TIOCGWINSZ");
		return 1;
	}
	printf("%d %d\n", argp.ws_row, argp.ws_col);
	return 0;
}
