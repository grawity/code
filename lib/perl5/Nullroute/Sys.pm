package Nullroute::Sys;
use base "Exporter";
use POSIX;
use Nullroute::Lib qw(forked readfile);
use Sys::Hostname qw(hostname);

our @EXPORT = qw(
	daemonize
	hostid
	bootid
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
	exit if $pid;
	if (POSIX::setsid() < 0) {
		warn "setsid failed: $!";
	}
}

sub hostid {
	my @id_files = (
		"/etc/machine-id",
		"/var/lib/dbus/machine-id",
		"/var/db/dbus/machine-id",
	);
	for my $file (@id_files) {
		return readfile($file) if -f $file;
	}
	return "name=".hostname();
}

sub bootid {
	my $id_file = "/proc/sys/kernel/random/boot_id";
	return readfile($id_file) if -f $id_file;
	return undef;
}

1;
