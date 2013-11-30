#include <stdbool.h>
#include <string.h>
#include <stdio.h>
#include <libudev.h>
#include <poll.h>

int main(void) {
	struct udev *udev;
	struct udev_monitor *mon;
	struct pollfd pf[1];
	int ret;

	udev = udev_new();

	mon = udev_monitor_new_from_netlink(udev, "udev");

	pf[0] = (struct pollfd) {
			.fd = udev_monitor_get_fd(mon),
			.events = POLLIN,
		};

	udev_monitor_filter_add_match_subsystem_devtype(mon, "power_supply", NULL);
	
	udev_monitor_enable_receiving(mon);

	while ((ret = poll(pf, 1, -1)) >= 0) {
		struct udev_device *dev;
		const char *sysname, *value;
		bool is_online;

		dev = udev_monitor_receive_device(mon);

		sysname = udev_device_get_sysname(dev);
		if (strncmp(sysname, "AC", 2) != 0)
			continue;

		value = udev_device_get_sysattr_value(dev, "online");
		is_online = (value && *value == '1');

		if (is_online) {
			printf("online\n");
		} else {
			printf("offline\n");
			break;
		}
	}

	return 0;
}
