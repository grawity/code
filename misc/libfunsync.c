/* libfunsync - preload library to prevent svnsync from calling fsync() for
 * every revision, as it only slows down operations greatly */

void sync(void) {
	return;
}

int fsync(int fd) {
	return 0;
}

int fdatasync(int fd) {
	return 0;
}
