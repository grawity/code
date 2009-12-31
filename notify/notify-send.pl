#!/usr/bin/perl
# r20091107
use strict;
#use brain;
use Irssi;
use Socket;
use vars qw($VERSION %IRSSI);
$VERSION = "0.1";
%IRSSI = (
	authors => "grawity",
	contact => "grawity\@gmail.com",
	name => "notify-send",
	description => "Sends hilight messages to a remote (well, local) desktop over UDP.",
	license => "WTFPLv2",
);

# Don't modify this; instead use /set notify_host
Irssi::settings_add_str("libnotify", "notify_host", "localhost:22754");

my $appname = "irssi";
my $icon = "notification-message-IM";

my ($dbus, $dservice, $dobject);
eval {
	require Net::DBus;
	$dbus = Net::DBus->session;
	$dservice = $dbus->get_service("org.freedesktop.Notifications");
	$dobject = $dservice->get_object("/org/freedesktop/Notifications",
		"org.freedesktop.Notifications");
}

sub send_udp($$$$) {
	my ($title, $text, $host, $port) = @_;

	my $rawmsg = join " | ", ($appname, $icon, $title, $text);

	my $rcpt = sockaddr_in($port, inet_aton($host));
	socket(SOCK, PF_INET, SOCK_DGRAM, getprotobyname("udp"));
	send(SOCK, $rawmsg, 0, $rcpt);
}

sub send_dbus($$) {
	my ($title, $text) = @_;

	if (defined $dobject) {
		$dobject->Notify($appname, 0, $icon, $title, $text, [], {}, 3000);
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
			send_dbus($title, $text);
		}
		else {
			$dest =~ /^(.+):([0-9]{1,5})$/;
			send_udp($title, $text, $1, $2);
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
