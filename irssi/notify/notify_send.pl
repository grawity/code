#!/usr/bin/perl
# Requirements:
#   libnotify over DBus:
#     preferred: Net::DBus module
#     alternate: notify-send binary (from libnotify-bin)
#   TCP or UDP over IPv6:
#     IO::Socket::INET6 module
#   TCP/SSL:
#     IO::Socket::SSL
#
# Settings:
#
# (string) notify_targets = "dbus"
#   Space-separated list of targets to send notifications to. Possible values:
#       dbus
#       file!<path>
#       tcp!<host>!<port>
#       udp!<host>!<port>
#       unix!<address>
#       unix!(stream|dgram)!<address>
#       ssl!<host>!<port>
#
# Notes:
#
#   - tcp and udp will only use the first address from DNS (due to use of
#     non-blocking sockets; fork() is a pain in irssi)
#
#   - By default, only messages containing your nickname will be matched;
#     /hilights will not be used due to limitations in Irssi. I *could* use
#     signal "print text", but then I couldn't split a message to title
#     (sender) and text in a theme-agnostic way. Because of this, notify-send
#     only checks a list of regexps, defined in on_message() below.

use strict;
use vars qw($VERSION %IRSSI);

use Irssi;
use Socket;
use IO::Socket::INET;
use IO::Socket::UNIX;

$VERSION = "0.6";
%IRSSI = (
	name        => 'notify-send',
	description => 'Sends hilight messages over DBus or Intertubes.',
	authors     => 'Mantas Mikulėnas',
	contact     => 'grawity@gmail.com',
	license     => 'WTFPL v2 <http://sam.zoy.org/wtfpl/>',
);

my ($dbus, $dbus_service, $libnotify);
my $appname = "irssi";
my $icon = "notification-message-IM";

sub on_message {
	my ($server, $msg, $nick, $userhost, $target, $type) = @_;
	my $mynick = $server->{nick};
	my $channel = $server->ischannel($target);

	# skip server notices
	return if !defined $userhost;

	# if public, check for hilightness
	return if $channel and !(
		# put hilight rules here, separated by 'or'
		$msg =~ /\Q$mynick/i
		#or $msg =~ /porn/i
	);

	# ignore services
	return if !$channel and (
		$nick =~ /^(nick|chan|memo|oper|php)serv$/i
	);

	my $title = $nick;
	$title .= " on $target" if $channel;

	# send notification to all dests
	my $dests = Irssi::settings_get_str("notify_targets");
	foreach my $dest (split / /, $dests) {
		my @ret = notify($dest, $title, $msg);
		Irssi::print("Could not notify $dest: $ret[1]") if !$ret[0];
	}
}

sub xml_escape($) {
	$_ = shift; s/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; return $_;
}

sub getserv($$) {
	my ($name, $proto) = @_;
	if ($name =~ /^[0-9]+$/) {
		return int $name;
	}
	my ($rname, $aliases, $port, $rproto) = getservbyname($name, $proto);
	return $port;
}

sub send_inet($$$$) {
	my ($data, $proto, $host, $service) = @_;
	my $port = getserv($service, $proto)
		or return 0, "Unknown service '$service/$proto'";
	my $sock;
	my %sock_args = (
		PeerAddr => $host,
		PeerPort => $port,
		Proto => $proto,
		Blocking => 0,
	);
	if (eval {require IO::Socket::INET6}) {
		$sock = IO::Socket::INET6->new(%sock_args);
	} elsif ($host =~ /:/) {
		return 0, "IPv6 support requires IO::Socket::INET6";
	} else {
		$sock = IO::Socket::INET->new(%sock_args);
	}
	if (defined $sock) {
		print $sock $data;
		$sock->close();
		return 1;
	} else {
		return 0, $!;
	}
}

sub send_inetssl($$$) {
	my ($data, $host, $service) = @_;
	my $port = getserv($service, "tcp")
		or return 0, "Unknown service '$service/tcp'";
	my $sock;
	my %sock_args = (
		PeerAddr => $host,
		PeerPort => $port,
		Proto => 'tcp',
		Blocking => 0,
		SSL_version => 'TLSv1',
		SSL_ca_path => '/etc/ssl/certs',
	);
	if (eval {require IO::Socket::SSL}) {
		$sock = IO::Socket::SSL->new(%sock_args);
	} else {
		return 0, "SSL support requires IO::Socket::SSL";
	}
	if (defined $sock) {
		print $sock $data;
		$sock->close();
		return 1;
	} else {
		return 0, $!;
	}
}

sub send_unix($$$) {
	my ($data, $type, $address) = @_;
	my $sock = IO::Socket::UNIX->new(
		Type => ($type eq 'stream'? SOCK_STREAM : SOCK_DGRAM),
		Peer => $address
	);
	if (defined $sock) {
		print $sock $data;
		$sock->close();
		return 1;
	} else {
		return 0, $!;
	}
}

sub send_file($$) {
	my ($data, $path) = @_;
	if (open my $fh, ">>", $path) {
		print $fh $data;
		close $fh;
		return 1;
	} else {
		return 0, $!;
	}
}

sub send_libnotify($$) {
	my ($title, $text) = @_;
	$text = xml_escape($text);

	if (!defined $dbus and eval {require Net::DBus}) {
		$dbus = Net::DBus->session;
		$dbus_service = $dbus->get_service("org.freedesktop.Notifications");
		$libnotify = $dbus_service->get_object("/org/freedesktop/Notifications");
	}

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

sub notify($$$) {
	my ($dest, $title, $text) = @_;
	my $rawmsg = join(" | ", $appname, $icon, $title, $text)."\n";

	if ($dest eq "dbus") {
		send_libnotify($title, $text);
	} elsif ($dest =~ /^(tcp|udp)!(.+?)!(.+?)$/) {
		send_inet($rawmsg, $1, $2, $3);
	} elsif ($dest =~ /^file!(.+)$/) {
		send_file($rawmsg, $1);
	} elsif ($dest =~ /^unix!(stream|dgram)!(.+)$/) {
		send_unix($rawmsg, $1, $2);
	} elsif ($dest =~ /^unix!(.+)$/) {
		send_unix($rawmsg, "stream", $1);
	} elsif ($dest =~ /^ssl!(.+?)!(.+?)$/) {
		send_inetssl($rawmsg, $1, $2);
	} else {
		$dest =~ /^([^!]+)/;
		0, "Unsupported address '$1'";
	}
}

Irssi::settings_add_str("libnotify", "notify_targets", "dbus");

Irssi::signal_add "message public", sub {
	on_message @_, "message"
};
Irssi::signal_add "message private", sub {
	on_message @_, "private"
};
Irssi::signal_add "message irc action", sub {
	on_message @_, "action"
};
Irssi::signal_add "message irc notice", sub {
	on_message @_, "notice"
};
