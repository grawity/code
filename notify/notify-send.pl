#!/usr/bin/perl
# Requirements:
#   libnotify over DBus:
#     Net::DBus

# Settings:
#
# (string) notify_host = "dbus"
#   Space-separated list of destinations.
#   A destination can be either 'dbus' to trigger libnotify locally,
#   or a host:port pair for UDP notifications (to notify-receive.pl)

use strict;

use Irssi;
use Socket;
use vars qw($VERSION %IRSSI);
$VERSION = "0.1";
%IRSSI = (
	authors     => "Mantas Mikulėnas",
	contact     => "grawity\@gmail.com",
	name        => "notify-send",
	description => "Sends hilight messages over DBus or UDP.",
	license     => "WTFPL v2 <http://sam.zoy.org/wtfpl/>",
);

# Don't modify this; instead use /set notify_host
Irssi::settings_add_str("libnotify", "notify_host", "dbus");

my $appname = "irssi";
my $icon = "notification-message-IM";

my ($dbus, $dservice, $libnotify);
eval {
	require Net::DBus;
	$dbus = Net::DBus->session;
	$dservice = $dbus->get_service("org.freedesktop.Notifications");
	$libnotify = $dservice->get_object("/org/freedesktop/Notifications",
		"org.freedesktop.Notifications");
};

sub xml_escape($) {
	my ($_) = @_;
	s/&/\&amp;/g;
	s/</\&lt;/g;
	s/>/\&gt;/g;
	s/"/\&quot;/g;
	return $_;
}

sub send_udp($$$$) {
	my ($title, $text, $host, $port) = @_;

	my $rawmsg = join " | ", ($appname, $icon, $title, $text);

	my $rcpt = sockaddr_in($port, inet_aton($host));
	socket(SOCK, PF_INET, SOCK_DGRAM, getprotobyname("udp"));
	send(SOCK, $rawmsg, 0, $rcpt);
}

sub send_libnotify($$) {
	my ($title, $text) = @_;
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

sub on_message {
	my ($server, $msg, $nick, $userhost, $target, $type) = @_;
	my $mynick = $server->{nick};
	my $channel = $server->ischannel($target);
	#my $channel = ($target =~ /^[#+&]/);

	# skip server notices
	return if !defined $userhost;

	# if public, check for hilightness
	return if $channel and !(
		# put hilight rules here
		$msg =~ /$mynick/
	);

	# ignore services
	return if !$channel and (
		$nick =~ /^(nick|chan|memo|oper)serv$/i
	);

	my $title = $nick;
	$title .= " on $target" if $channel;

	my $dests = Irssi::settings_get_str("notify_host");
	foreach my $dest (split / /, $dests) {
		if ($dest eq "dbus") {
			send_libnotify($title, $msg);
		}
		else {
			$dest =~ /^(.+):([0-9]{1,5})$/;
			send_udp($title, $msg, $1, $2);
		}
	}
}

Irssi::signal_add("message public", sub {
	on_message @_, "message"
});

Irssi::signal_add("message private", sub  {
	on_message @_, "private"
});

Irssi::signal_add("message irc action", sub {
	on_message @_, "action"
});

Irssi::signal_add("message irc notice", sub {
	on_message @_, "notice"
});
