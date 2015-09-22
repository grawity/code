#include <stdbool.h>
#include <string.h>
#include <stdio.h>
#include <libudev.h>
#include <poll.h>
#include <err.h>

static inline bool is_online(struct udev_device *dev) {
	const char *value = udev_device_get_sysattr_value(dev, "online");

	return (value && *value == '1');
}

int main(void) {
	struct udev *udev;
	struct udev_monitor *mon;
	struct udev_enumerate *enumerate;
	struct udev_list_entry *entry;
	struct udev_device *dev = NULL;
	struct pollfd pf[1];
	int ret;

	udev = udev_new();

	/* enumerate all devices */

	enumerate = udev_enumerate_new(udev);
	if (!enumerate)
		errx(1, "could not create udev enumerator");

	ret = udev_enumerate_add_match_subsystem(enumerate, "power_supply");
	if (ret < 0)
		errx(1, "could not add subsystem match");

	ret = udev_enumerate_add_match_sysattr(enumerate, "type", "Mains");
	if (ret < 0)
		errx(1, "could not add sysattr match");

	ret = udev_enumerate_scan_devices(enumerate);
	if (ret < 0)
		errx(1, "could not scan devices");

	for (entry = udev_enumerate_get_list_entry(enumerate);
		entry != NULL;
		entry = udev_list_entry_get_next(entry))
	{
		char *path = udev_list_entry_get_name(entry);
		dev = udev_device_new_from_syspath(udev, path);
		if (getenv("DEBUG"))
			warnx("found device %s", path);
	}

	if (!dev)
		errx(1, "no device found, exiting");

	if (!is_online(dev))
		errx(0, "offline, exiting");

	warnx("online, waiting");

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

		if (!is_online(dev))
			errx(0, "went offline");
	}

	return 0;
}
