#include <stdbool.h>
#include <string.h>
#include <stdio.h>
#include <libudev.h>
#include <poll.h>

static inline bool is_online(struct udev_device *dev) {
	const char *value = udev_device_get_sysattr_value(dev, "online");

	return (value && *value == '1');
}

int main(void) {
	struct udev *udev;
	struct udev_monitor *mon;
	struct udev_device *dev;
	struct pollfd pf[1];
	int ret;

	udev = udev_new();

	dev = udev_device_new_from_subsystem_sysname(udev, "power_supply", "AC0");

	if (is_online(dev)) {
		printf("online, waiting\n");
	} else {
		printf("offline, exiting\n");
		return 0;
	}

	mon = udev_monitor_new_from_netlink(udev, "udev");

	pf[0] = (struct pollfd) {
			.fd = udev_monitor_get_fd(mon),
			.events = POLLIN,
		};

	udev_monitor_filter_add_match_subsystem_devtype(mon,
							udev_device_get_subsystem(dev),
							udev_device_get_devtype(dev));
	
	udev_monitor_enable_receiving(mon);

	while ((ret = poll(pf, 1, -1)) >= 0) {
		struct udev_device *dev;
		const char *sysname;

		dev = udev_monitor_receive_device(mon);

		sysname = udev_device_get_sysname(dev);
		if (strncmp(sysname, "AC", 2) != 0)
			continue;

		if (!is_online(dev)) {
			printf("offline\n");
			return 0;
		}
	}

	return 0;
}
