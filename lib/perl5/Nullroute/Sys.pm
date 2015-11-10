package Nullroute::Sys;
use base "Exporter";
use POSIX ();
use Nullroute::Lib;
use Sys::Hostname qw(hostname);

our @EXPORT = qw(
	daemonize
	hostid
	bootid
	sessionid
);

my $hostid;
my $bootid;
my $sessionid;

sub daemonize {
	chdir("/")
		or _die("could not chdir to /: $!");
	open(STDIN, "<", "/dev/null")
		or _die("could not open </dev/null: $!");
	open(STDOUT, ">", "/dev/null")
		or _die("could not open >/dev/null: $!");
	my $pid = fork()
		// _die("could not fork: $!");
	exit if $pid;
	POSIX::setsid() >= 0
		or _warn("could not leave session: $!");
}

sub _hostid {
	my @id_files = (
		"/etc/machine-id",
		"/var/lib/dbus/machine-id",
		"/var/db/dbus/machine-id",
	);
	for my $file (@id_files) {
		return readfile($file) if -f $file;
	}
	if ($^O eq "freebsd") {
		my $file = "/etc/hostid";
		if (-e $file && (stat $file)[7] > 10) {
			my $id = readfile($file);
			$id =~ s/-//g;
			return $id;
		}
	}
	return "name=".hostname();
}

sub hostid { $hostid //= _hostid(); }

sub _bootid {
	if ($^O eq "linux") {
		my $f = "/proc/sys/kernel/random/boot_id";
		return readfile($f) if -r $f;
	}
	return undef;
}

sub bootid { $bootid //= _bootid(); }

sub _sessionid {
	my @items;
	if (defined $ENV{XDG_SESSION_ID}) {
		return "xdg.".$ENV{XDG_SESSION_ID};
	}
	return undef;
}

sub sessionid { $sessionid //= _sessionid(); }

sub _ttyname {
	if ((-t 1) && (my $name = POSIX::ttyname(1))) {
		$name =~ s!^/dev/!!;
		return $name;
	}
}

1;
