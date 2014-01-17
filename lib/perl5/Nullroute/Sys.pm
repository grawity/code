package Nullroute::Sys;
use base "Exporter";
use POSIX;
use Nullroute::Lib qw(forked readfile);
use Sys::Hostname qw(hostname);

our @EXPORT = qw(
	daemonize
);

sub daemonize {
	chdir("/")
		or die "can't chdir to /: $!";
	open(STDIN, "<", "/dev/null")
		or die "can't read /dev/null: $!";
	open(STDOUT, ">", "/dev/null")
		or die "can't write /dev/null: $!";
	my $pid = fork()
		// die("can't fork: $!");

	if ($pid) {
		exit;
	} else {
		if (POSIX::setsid() < 0) {
			warn "setsid failed: $!";
		}
	}
}

sub gethostid {
	if (-f "/etc/machine-id") {
		return readfile("/etc/machine-id");
	} elsif (-f "/var/lib/dbus/machine-id") {
		return readfile("/var/lib/dbus/machine-id");
	} else {
		return "name=".hostname();
	}
}

sub getbootid {
	if (-f "/proc/sys/kernel/random/boot_id") {
		return readfile("/proc/sys/kernel/random/boot_id");
	} else {
		return undef;
	}
}

1;
