/*
 * Creates a new filesystem namespace
 * http://glandium.org/blog/?p=217
 * Modified for setuid
 *
 * If you mount something in a shell spawned by newns, only other processes
 * from the same shell will see those new mounts.
 *
 * Can be used to have per-user /tmp or whatever.
 *   bashone# newns
 *   bashtwo# mount --bind ~/my-personal-tmp /tmp
 *   bashtwo# touch /tmp/hai
 *
 *   anotherwindow# ls /tmp/hai
 *   ls: no such file or directory
 */
#include <sched.h>
#include <syscall.h>
#include <unistd.h>
#include <errno.h>
#include <stdio.h>

int main(int argc, char *argv[]) {

	int uid = getuid();
	int euid = geteuid();

	setreuid(euid, euid);

	//syscall(SYS_unshare, CLONE_NEWNS);
	if (unshare(CLONE_NEWNS) == -1) {
		int e = errno;
		if (e == EPERM) {
			fprintf(stderr, "newns: unshare() failed: Permission denied\n");
			return e;
		}
		else {
			fprintf(stderr, "newns: unshare() failed\n");
			return e;
		}
	}

	setreuid(uid, uid);

	if (argc > 1)
		return execvp(argv[1], &argv[1]);
	else
		return execv("/bin/sh", NULL);
}
