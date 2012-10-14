#include <stdio.h>
#include <stdlib.h>
#include <sys/prctl.h>
#include <signal.h>
#include <sys/wait.h>
#include <unistd.h>

#ifndef PR_SET_CHILD_SUBREAPER
#define PR_SET_CHILD_SUBREAPER 36
#endif

int main(int argc, char *argv[]) {
	pid_t pid;

	if (argc < 2) {
		fprintf(stderr, "Usage: subreaper <cmd> [args...]\n");
		return 2;
	}

	if (prctl(PR_SET_CHILD_SUBREAPER, 1) < 0)
		perror("set_subreaper");

	signal(SIGCHLD, SIG_IGN);

	pid = fork();
	if (pid < 0) {
		perror("fork");
		exit(1);
	}
	else if (pid) {
		waitpid(pid, 0, 0);
		exit(0);
	}
	else {
		execvp(argv[1], argv+1);
		perror("execv");
		exit(1);
	}
}
