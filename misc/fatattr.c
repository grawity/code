#include <stdio.h>
#include <stdint.h>
#include <linux/msdos_fs.h>
#include <sys/ioctl.h>
#include <fcntl.h>

const struct { char fmt; uint32_t bit; } attrs[] = {
	{ 'a', ATTR_ARCH },
	{ 'd', ATTR_DIR },
	{ 'h', ATTR_HIDDEN },
	{ 'r', ATTR_RO },
	{ 's', ATTR_SYS },
	{ 'v', ATTR_VOLUME },
	0,
};

uint32_t fat_fgetattr(int fd)
{
	int r, attr;

	r = ioctl(fd, FAT_IOCTL_GET_ATTRIBUTES, &attr);
	if (r < 0)
		err(1, "could not get attributes");

	return attr;
}

char *fat_attr2string(uint32_t attr)
{
	static char buf[sizeof(attr) + 1];
	int i;

	for (i = 0; attrs[i].bit; i++)
		buf[i] = (attr & attrs[i].bit) ? attrs[i].fmt : '-';
	buf[++i] = 0;
	return buf;
}

int main(int argc, char *argv[])
{
	int i, r;
	uint32_t want_add = 0;
	uint32_t want_rem = 0;

	for (i = 1; i < argc; i++) {
		char *file;
		int fd;
		uint32_t attr;

		file = argv[i];
		if (file[0] == '+' || file[0] == '-') {
			int j;
			uint32_t *want;

			for (j = 0; file[j]; j++) {
				switch (file[j]) {
				case '+':
					want = &want_add; break;
				case '-':
					want = &want_rem; break;
				case 'a':
					*want |= ATTR_ARCH; break;
				}
			}
		}

		fd = open(file, O_RDONLY);
		if (fd < 0)
			err(1, "could not open file");
		attr = fat_fgetattr(fd);
		printf("%s %s\n", fat_attr2string(attr), file);
		close(fd);
	}
	
	return 0;
}
