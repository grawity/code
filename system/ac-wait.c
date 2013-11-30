#include <stdbool.h>
#include <string.h>
#include <stdio.h>
#include <libudev.h>
#include <poll.h>

int main(void) {
	struct udev *udev;
	struct udev_monitor *mon;
	struct udev_device *ac, *dev;
	const char *dtype, *val;
	int ret;

	udev = udev_new();

	ac = udev_device_new_from_subsystem_sysname(udev, "power_supply", "AC0");

	val = udev_device_get_sysattr_value(ac, "online");
	printf("%s\n", val);

	mon = udev_monitor_new_from_netlink(udev, "udev");
	dtype = udev_device_get_devtype(ac);
	udev_monitor_filter_add_match_subsystem_devtype(mon, "power_supply", dtype);

	struct pollfd pf[1];

	pf[0] = (struct pollfd) {
			.fd = udev_monitor_get_fd(mon),
			.events = POLLIN,
		};
	
	udev_monitor_enable_receiving(mon);

	while ((ret = poll(pf, 1, -1)) >= 0) {
		const char *sysname, *value;
		bool is_online;

		dev = udev_monitor_receive_device(mon);
		sysname = udev_device_get_sysname(dev);
		if (strncmp(sysname, "AC", 2) != 0)
			continue;
		value = udev_device_get_sysattr_value(dev, "online");
		is_online = (value && *value == '1');

		if (is_online) {
			printf("online %s\n", sysname);
		} else {
			printf("offline\n");
			break;
		}
	}

	return 0;
}
