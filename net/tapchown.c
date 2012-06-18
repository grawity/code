#include <sys/types.h>
#include <sys/ioctl.h>
#include <net/if.h>
#include <fcntl.h>
#include <linux/if_tun.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define CLONEDEV "/dev/net/tun"

char *arg0;

static int usage() {
	printf("Usage: %s <ifname> <uid>\n", arg0);
	return 2;
}

int main(int argc, char *argv[]) {
	struct ifreq ifr;
	char *ifname;
	int fd, r;
	uid_t owner;
	int iftype = -1;

	arg0 = argv[0];

	if (argc < 3) {
		fprintf(stderr, "%s: missing arguments\n", arg0);
		return usage();
	}

	ifname = argv[1];
	owner = atoi(argv[2]);

	if (iftype == -1) {
		if (strncmp(ifname, "tun", 3) == 0)
			iftype = IFF_TUN;
		else if (strncmp(ifname, "tap", 3) == 0)
			iftype = IFF_TAP;
		else {
			fprintf(stderr, "Unknown device type\n");
			return 3;
		}
	}

	fd = open(CLONEDEV, O_RDWR);
	if (!fd) {
		perror("open(" CLONEDEV ")");
		return 1;
	}

	memset(&ifr, 0, sizeof(ifr));
	ifr.ifr_flags = iftype | IFF_NO_PI;
	strncpy(ifr.ifr_name, ifname, IFNAMSIZ);
	r = ioctl(fd, TUNSETIFF, &ifr);
	if (r < 0) {
		perror("ioctl(TUNSETIFF)");
		return 1;
	}

	r = ioctl(fd, TUNSETOWNER, owner);
	if (r < 0) {
		perror("ioctl(TUNSETOWNER)");
		return 1;
	}

	close(fd);
	return 0;
}
