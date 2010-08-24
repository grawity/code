#!/usr/bin/perl
# Requirements:
#   libnotify over DBus:
#     preferred: Net::DBus module
#     alternate: notify-send binary (from libnotify-bin)
#   TCP or UDP over IPv6:
#     IO::Socket::INET6 module
#
# Settings:
#
# (string) notify_host = "dbus"
#   Space-separated list of destinations. Possible destinations are:
#       dbus
#       tcp!<host>!<port>
#       udp!<host>!<port>
#       unix!<address>
#
# Notes:
#
#   - tcp and udp will only use the first address from DNS (due to use of
#     non-blocking sockets; fork() is a pain in irssi)

use strict;
use vars qw($VERSION %IRSSI);

use Irssi;
use IO::Socket::INET;
use IO::Socket::UNIX;

$VERSION = "0.4";
%IRSSI = (
	name        => 'notify-send',
	description => 'Sends hilight messages over DBus or Intertubes.',
	authors     => 'Mantas Mikulėnas',
	contact     => 'grawity@gmail.com',
	license     => 'WTFPL v2 <http://sam.zoy.org/wtfpl/>',
);

# Don't modify this; instead use /set notify_host
Irssi::settings_add_str("libnotify", "notify_host", "dbus");

my ($dbus, $dbus_service, $libnotify);
my $appname = "irssi";
my $icon = "notification-message-IM";

sub xml_escape($) {
	$_ = shift; s/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; return $_;
}

sub send_inet($$$$) {
	my ($data, $proto, $host, $port) = @_;
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
		Irssi::print("notify-send: IPv6 support requires IO::Socket::INET6");
		return 0;
	} else {
		$sock = IO::Socket::INET->new(%sock_args);
	}
	if (defined $sock) {
		print $sock $data;
		$sock->close();
	}
}

sub send_unix($$) {
	my ($data, $address) = @_;
	my $sock = IO::Socket::UNIX->new(Peer => $address);
	if (defined $sock) {
		print $sock $data;
		$sock->close();
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

sub send_notification($$) {
	my ($title, $text) = @_;
	my $rawmsg = join(" | ", $appname, $icon, $title, $text);
	my $dests = Irssi::settings_get_str("notify_host");
	foreach my $dest (split / /, $dests) {
		if ($dest eq "dbus") {
			send_libnotify($title, $text);
		} elsif ($dest =~ /^(tcp|udp)!(.+?)!([0-9]+)$/) {
			send_inet($rawmsg, $1, $2, int $3);
		} elsif ($dest =~ /^unix!(.+)$/) {
			send_unix($rawmsg, $1);
		} else {
			print "$IRSSI{name}: unsupported address '$dest'";
		}
	}
}

sub on_message {
	my ($server, $msg, $nick, $userhost, $target, $type) = @_;
	my $mynick = $server->{nick};
	my $channel = $server->ischannel($target);

	# skip server notices
	return if !defined $userhost;

	# if public, check for hilightness
	return if $channel and !(
		# put hilight rules here
		$msg =~ /\Q$mynick/
	);

	# ignore services
	return if !$channel and (
		$nick =~ /^(nick|chan|memo|oper)serv$/i
	);

	my $title = $nick;
	$title .= " on $target" if $channel;

	send_notification($title, $msg);
}

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
