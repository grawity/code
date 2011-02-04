#!/usr/bin/env perl
use warnings;
use strict;

use POSIX qw/setsid/;
use IPC::Open2;
use IPC::Run qw/run/;

use Data::Dumper;

use constant {
	MOUSE_LEFT => 1,
	MOUSE_MIDDLE => 2,
	MOUSE_RIGHT => 3,
	MOUSE_SCROLL_UP => 4,
	MOUSE_SCROLL_DOWN => 5,
};

our $Config;
my $Events;
my $Keys;

sub ixp_create {
	my ($path) = @_;
	open my $fd, "|-", ("wmiir", "create", $path);
	return $fd;
}
sub ixp_write {
	my ($path) = @_;
	open my $fd, "|-", ("wmiir", "write", $path);
	return $fd;
}
sub ixp_read {
	my ($path) = @_;
	open my $fd, "-|", ("wmiir", "read", $path);
	return $fd;
}
sub ixp_remove {
	my ($path) = @_;
	system("wmiir", "remove", $path);
}
sub ixp_list {
	my ($path) = @_;
	open my $fd, "-|", ("wmiir", "ls", $path);
	return $fd;
}
sub ixp_xcreate {
	my ($path, @lines) = @_;
	my $fd = ixp_create $path;
	foreach my $line (@lines) {
		print $fd "$line\n";
	}
	close $fd;
}
sub ixp_xwrite {
	my ($path, @lines) = @_;
	my $fd = ixp_write $path;
	foreach my $line (@lines) {
		print $fd "$line\n";
	}
	close $fd;
}

# Write "key value" pairs
sub ctl {
	my ($fd, %values) = @_;
	foreach my $key (keys %values) {
		print $fd $key, " ", $values{$key}, "\n";
	}
}
sub ctl_create {
	my ($path, %values) = @_;
	my $fd = ixp_create $path;
	ctl $fd, %values;
	close $fd;
}
sub ctl_write {
	my ($path, %values) = @_;
	my $fd = ixp_write $path;
	ctl $fd, %values;
	close $fd;
}

# Handler for /event input
sub on_event {
	my ($event, @args) = @_;
	if (!exists $Events->{$event}) {
		return 0;
	}

	my ($argcount, $handler) = @{$Events->{$event}};
	if ($#args+1 < $argcount) {
		@args = split " ", $args[0], $argcount;
	}
	&$handler(@args);
}

sub on_key {
	my ($key) = @_;
	$key =~ s/^$Config->{modkey}-/Modkey-/;
	if (!exists $Keys->{$key}) {
		return 0;
	}
	my $handler = $Keys->{$key};
	&$handler;
}

# Tag helper functions
sub this_tag {
	my $fd = ixp_read "/tag/sel/ctl";
	chomp(my $tag = <$fd>);
	close $fd;
	return $tag;
}
sub tags {
	my $fd = ixp_list "/tag";
	my @tags = ();
	while (<$fd>) {
		chomp; s|/$||;
		!/^sel$/ and push @tags, $_;
	}
	return @tags;
}
sub next_tag {
	my @alltags = tags;
	my $this = this_tag;
	my $found = 0;
	foreach my $t (@alltags) {
		if ($found) { return $t; }
		else { $found = ($t eq $this); }
	}
	return $alltags[0];
}
sub prev_tag {
	my @alltags = tags;
	my $this = this_tag;
	my $last = $alltags[$#alltags];
	foreach my $t (@alltags) {
		if ($t eq $this) { return $last; }
		else { $last = $t; }
	}
	return $alltags[$#alltags];
}

# Fork/exec an external program
sub spawn {
	my (@args) = @_;
	if (fork == 0) {
		exec { $args[0] } @args or exit;
	}
}
# spawn() in a new session
sub spawns {
	my (@args) = @_;
	if (fork == 0) {
		setsid();
		exec { $args[0] } @args or exit;
	}
}

sub keys {
	my @k = keys %@Keys;
	map {s/^Modkey-/$Config->{modkey}-/} @k;
}

sub suicide {
	print "Slaying -$$\n";
	kill 15, -$$;
}
$SIG{INT} = \&suicide;

$Config = do "wmii-config.pl";
	die "Couldn't parse config: $@" if $@;
$Events = do "wmii-events.pl";
	die "Couldn't parse events: $@" if $@;
$Actions = do "wmii-actions.pl";
$Keys = do "wmii-keys.pl";

ixp_xwrite("/event", "Start $$ $0");

ctl_write("/ctl",
	font => $Config->{font},
	fontpad => "1 1 1 1",
	focuscolors => $Config->{colors}{focus},
	normcolors => $Config->{colors}{normal},
	grabmod => $Config->{modkey},
	colmode => "default",
);
system("xsetroot", "-solid", $Config->{background});

my $eventfd = ixp_read "/event";
while (my $line = <$eventfd>) {
	chomp $line;
	print ">> $line\n";
	my ($event, $args) = split " ", $line, 2;
	on_event($event, $args);
}
close $eventfd;
