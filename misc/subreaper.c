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
	pid_t pid = fork();
	if (pid < 0) {
		perror("fork");
		exit(1);
	}
	else if (pid) {
		prctl(PR_SET_CHILD_SUBREAPER, 1);
		signal(SIGCHLD, SIG_IGN);
		waitpid(pid, 0, 0);
		exit(0);
	}
	else {
		execvp(argv[1], argv+1);
		perror("execv");
		exit(1);
	}
}
