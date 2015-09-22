#include <stdbool.h>
#include <string.h>
#include <stdio.h>
#include <libudev.h>
#include <poll.h>
#include <stdlib.h>
#include <unistd.h>
#include <err.h>

static inline bool is_online(struct udev_device *dev) {
	const char *value = udev_device_get_sysattr_value(dev, "online");

	return (value && *value == '1');
}

static struct udev_device * find_device(struct udev *udev) {
	struct udev_enumerate *enumerate;
	struct udev_list_entry *entry;
	struct udev_device *dev = NULL;
	int ret;

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

	dev = NULL;

	for (entry = udev_enumerate_get_list_entry(enumerate);
		entry != NULL;
		entry = udev_list_entry_get_next(entry))
	{
		const char *path;

		path = udev_list_entry_get_name(entry);
		dev = udev_device_new_from_syspath(udev, path);
		if (getenv("DEBUG"))
			warnx("found device %s", path);
	}

	return dev;
}

static void monitor_device(struct udev *udev, struct udev_device *dev) {
	struct udev_monitor *mon;
	struct pollfd pf[1];
	int ret;

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

		if (is_online(dev))
			warnx("went online");
		else
			errx(0, "went offline");
	}
}

int main(int argc, char *argv[]) {
	struct udev *udev;
	struct udev_device *dev = NULL;
	bool wait_online = false;
	int opt;

	while ((opt = getopt(argc, argv, "w")) != -1) {
		switch (opt) {
		case 'w':
			wait_online = true;
			break;
		default:
			errx(1, "Usage: %s [-w]", argv[0]);
		}
	}

	udev = udev_new();

	dev = find_device(udev);

	if (!dev)
		errx(1, "no device found, exiting");

	if (is_online(dev))
		warnx("online, waiting");
	else if (wait_online)
		warnx("offline, waiting");
	else
		errx(0, "offline, exiting");

	monitor_device(udev, dev);

	return 0;
}
