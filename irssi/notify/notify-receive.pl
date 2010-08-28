#!/usr/bin/perl
# r20100710
use strict;
#use brain;
use Getopt::Long qw(:config bundling);
use IO::Socket;

my ($dbus, $libn_serv, $libnotify);

sub forked(&) {
	my $code = shift;
	my $pid = fork();
	if ($pid == 0) {
		exit &$code;
	} else {
		return $pid;
	}
}

sub xml_escape($) {
	my ($_) = @_; s/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; return $_;
}

sub handle_message($) {
	my ($message) = @_;
	my ($appname, $icon, $title, $text) = split / \| /, $message;

	if ($title eq "") { next; }
	#if ($appname eq "") { $appname = "unknown"; }

	send_libnotify($appname, $icon, $title, $text);
}

sub send_libnotify($$$$) {
	my ($appname, $icon, $title, $text) = @_;
	$text = xml_escape($text);

	if (defined $libnotify) {
		$libnotify->Notify($appname, 0, $icon, $title, $text, [], {}, 3000);
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

if (eval {require Net::DBus}) {
	$dbus = Net::DBus->session;
}

if (defined $dbus) {
	$libn_serv = $dbus->get_service("org.freedesktop.Notifications");
	$libnotify = $libn_serv->get_object("/org/freedesktop/Notifications");
}

### main loop

my $listen = shift @ARGV;

sub socket_inet($$$) {
	my ($proto, $laddr, $lport) = @_;

	my $sock;
	my %sock_args = (
		Proto => $proto,
		LocalAddr => $laddr,
		LocalPort => $lport,
		ReuseAddr => 1,
	);
	if (eval {require IO::Socket::INET6}) {
		$sock = IO::Socket::INET6->new(%sock_args)
			or die "socket: $!";
	} elsif ($laddr =~ /:/) {
		die "IO::Socket::INET6 required for IPv6\n";
	} else {
		$sock = IO::Socket::INET->new(%sock_args)
			or die "socket: $!";
	}
	return $sock;
}

sub accept_stream($) {
	my $sock = shift;
	while (my $insock = $sock->accept) {
		forked {
			chomp(my $data = <$insock>);
			close $insock;
			$data and handle_message($data);
		};
	}
}

sub accept_dgram($) {
	my $sock = shift;
	while ($sock->recv(my $data, 1024)) {
		chomp $data;
		$data and handle_message($data);
	}
}

if ($listen =~ /^(tcp|udp)!(.+)!(.+)$/) {
	my $proto = $1;
	my $laddr = ($2 eq '*'? undef : $2);
	my $lport = $3;

	my $sock;

	if ($proto eq 'tcp') {
		$sock = socket_inet($proto, $laddr, $lport);
		$sock->listen(1);
		accept_stream $sock;
	} elsif ($proto eq 'udp') {
		$sock = socket_inet($proto, $laddr, $lport);
		accept_dgram $sock;
	}

	close $sock;
} else {
	die "Unknown protocol\n";
}
