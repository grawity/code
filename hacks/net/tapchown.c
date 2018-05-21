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
	printf("Usage: %s {-n|-p} <ifname> <uid>\n", arg0);
	return 2;
}

int main(int argc, char *argv[]) {
	int iftype = -1, opt, fd, r;
	char *argp, *ifname;
	uid_t owner;
	struct ifreq ifr;

	arg0 = argv[0];

	while ((opt = getopt(argc, argv, "np")) != -1) {
		switch (opt) {
		case 'n':
			iftype = IFF_TUN;
			break;
		case 'p':
			iftype = IFF_TAP;
			break;
		default:
			return usage();
		}
	}

	if (argc - optind < 2) {
		fprintf(stderr, "%s: missing arguments\n", arg0);
		return usage();
	}

	argp   = argv[optind];
	ifname = argp++;
	owner  = atoi(argp++);

	if (iftype == -1) {
		if (strncmp(ifname, "tun", 3) == 0)
			iftype = IFF_TUN;
		else if (strncmp(ifname, "tap", 3) == 0)
			iftype = IFF_TAP;
		else {
			fprintf(stderr, "%s: unknown device type for '%s'\n",
				arg0, ifname);
			return 3;
		}
	}

	bzero(&ifr, sizeof(ifr));
	ifr.ifr_flags = iftype | IFF_NO_PI;
	strncpy(ifr.ifr_name, ifname, IFNAMSIZ);

	fd = open(CLONEDEV, O_RDWR);
	if (!fd) {
		fprintf(stderr, "%s: could not open control device %s: %m\n",
			arg0, CLONEDEV);
		return 1;
	}

	r = ioctl(fd, TUNSETIFF, &ifr);
	if (r < 0) {
		fprintf(stderr, "%s: could not select interface '%s' (TUNSETIFF): %m\n",
			arg0, ifname);
		return 1;
	}

	r = ioctl(fd, TUNSETOWNER, owner);
	if (r < 0) {
		fprintf(stderr, "%s: could not set interface owner to %d: %m\n",
			arg0, owner);
		return 1;
	}

	close(fd);
	return 0;
}
