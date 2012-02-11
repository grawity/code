#!perl
package Nullroute::Sys;
use Nullroute qw(readfile);
use Sys::Hostname qw(hostname);

sub gethostid {
	if (-f "/etc/machine-id") {
		return readfile("/etc/machine-id");
	} elsif (-f "/var/lib/dbus/machine-id") {
		return readfile("/var/lib/dbus/machine-id");
	} else {
		return "name=".hostname;
	}
}

sub getbootid {
	if (-f "/proc/sys/kernel/random/boot_id") {
		return readfile("/proc/sys/kernel/random/boot_id");
	} else {
		return undef;
	}
}

