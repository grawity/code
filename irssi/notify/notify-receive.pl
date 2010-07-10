#!/usr/bin/perl
# r20100710
use strict;
#use brain;
use IO::Socket;

sub xml_escape($) {
	my ($_) = @_; s/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; return $_;
}

### DBus libnotify

my ($dbus, $libnotify, $dobject);
eval {
	require Net::DBus;
	$dbus = Net::DBus->session;
	$libnotify = $dbus->get_service("org.freedesktop.Notifications");
	$dobject = $libnotify->get_object("/org/freedesktop/Notifications");
};

sub send_libnotify($$$$) {
	my ($appname, $icon, $title, $text) = @_;
	$text = xml_escape($text);
	if (defined $dobject) {
		$dobject->Notify($appname, 0, $icon, $title, $text, [], {}, 3000);
	}
	else {
		my @args = ("notify-send");
		push @args, "--icon=$icon" unless $icon eq "";
		# category doesn't do the same as appname, but still useful
		push @args, "--category=$appname" unless $appname eq "";
		push @args, $title;
		push @args, $text unless $text eq "";
		system @args;
	}
}

if (defined $dbus) {
	print "DBus: using Net::DBus\n";
}
else {
	print "DBus: Net::DBus not available, falling back to notify-send\n";
}

### UDP listener (the main loop)

my $ListenPort = shift @ARGV // 22754;

my $socket = IO::Socket::INET->new(
	Proto => 'udp',
	LocalPort => $ListenPort,
	Reuse => 1,
) or die "socket error: $!";

my ($message, $title, $text);

print "Waiting for notifications on *:$ListenPort\n";

while ($socket->recv($message, 1024)) {
	my ($port, $host) = sockaddr_in($socket->peername);
	$host = join '.', unpack "C*", $host;

	chomp $message;
	my ($appname, $icon, $title, $text) = split " | ", $message, 4;

	print "from:  $host:$port\n";
	print "app:   $appname\n";
	
	if ($title eq "") { next; }
	#if ($appname eq "") { $appname = "unknown"; }
	
	print "title: $title\n";
	print "text:  $text\n";

	send_libnotify($appname, $icon, $title, $text);
}
die "recv error: $!";

