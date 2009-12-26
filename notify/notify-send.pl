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

sub notify_send {
	my ($title, $text) = @_;
	my $icon = "notification-message-IM";

	#my $rawmsg = "irssi\n$icon\n$title\n$text\n";
	my $rawmsg = join "\n", "irssi", $icon, $title, $text;

	my $dests = Irssi::settings_get_str("notify_host");
	foreach my $dest (split / /, $dests) {
		$dest =~ /^(.+):([0-9]{1,5})$/;
		my ($dest_host, $dest_port) = ($1, $2);
		my $rcpt = sockaddr_in($dest_port, inet_aton($dest_host));
		socket(SOCK, PF_INET, SOCK_DGRAM, getprotobyname("udp"));
		send(SOCK, $rawmsg, 0, $rcpt);
	}
}

sub on_message {
	my ($server, $msg, $nick, $userhost, $target, $type) = @_;
	my $mynick = $server->{nick};
	my $channel = ($target =~ /^[#+&]/);

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
	if ($channel) {
		$title .= " on $target";
	}

	notify_send $title, $msg;
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
