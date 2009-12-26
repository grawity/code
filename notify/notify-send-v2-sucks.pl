#!/usr/bin/perl
use strict;
#use brain;
use Irssi;
use IO::Socket;
use vars qw($VERSION %IRSSI);
$VERSION = "0.1";
%IRSSI = (
	authors => "grawity",
	contact => "grawity\@gmail.com",
	name => "notify-send",
	description => "Sends hilight messages to a remote (well, local) desktop over UDP.",
	license => "WTFPLv2",
);

my $DestHost = "localhost";
my $DestPort = 22754;

my $socket = IO::Socket::INET->new(
	Proto => 'udp',
	PeerAddr => $DestHost,
	PeerPort => $DestPort,
) or die "socket error: $!";

sub ignore {
	my ($nick, $user, $host) = @_;
	return true if (
		$nick eq "Spikemcc"	
	);
}

sub notify {
	my ($icon, $title, $text) = @_;
	#print "[$title] $text";
	$text =~ s/&/&amp;/g;
	$text =~ s/</&lt;/g;
	$text =~ s/>/&gt;/g;
	my $data = join "\n", "irssi", $icon, $title, $text;
	$socket->send($data);
}

sub notice {
	my ($server, $message, $nick, $target) = @_;
	return if $nick =~ /^(Nick|Chan)Serv$/i;
	return if $nick =~ /^Aitvaras$/i;
	return if $nick =~ /^([a-z]\.)+[a-z]+$/;
	my $title = "Notice from $nick";
	my $text = $message;
	
	notify "notification-message-IM", $title, $text;
}
Irssi::signal_add_last("message irc notice", "notice");

sub action {
	my ($server, $message, $nick, $target) = @_;
	return unless $message =~ /grawity/;
	my $title = "$nick";
	my $text = $message;
	
	notify "notification-message-IM", $title, $text;
}
Irssi::signal_add_last("message irc action", "action");

sub private_message {
	my ($server, $message, $nick, $address) = @_;
	my $title = $nick;
	my $text = $message;
	
	notify "notification-message-IM", $title, $text;
}
Irssi::signal_add_last("message private", "private_message");

sub public_message {
	my ($server, $message, $nick, $address) = @_;
	return unless $message =~ /grawity/;
	my $title = $nick;
	my $text = $message;
	
	notify "notification-message-IM", $title, $text;
}
Irssi::signal_add_last("message public", "public_message");

sub kick {
	my ($server, $channel, $victim, $kicker, $victimAddr, $reason) = @_;
	return unless $victim eq $server->{nick};
	my $title = "$kicker has kicked you from $channel";
	my $text = "The reason was: $reason";
	
	notify undef, $title, $text;
}
Irssi::signal_add_last("message kick", "kick");

sub dcc_req {
	# received a DCC
	my ($dcc, $sender) = @_;
	my $title = $dcc->{nick};
	my $who = ($dcc->{target} eq $dcc->{mynick}) ? "you" : $dcc->{target};
	my $text;
	if ($dcc->{type} eq "GET") {
		$text = "wants to send $who a file:\n"
			. $dcc->{arg}." (".$dcc->{size}.")";
	}
	elsif ($dcc->{type} eq "CHAT") {
		$text = "wants to start a direct chat with $who";
	}
	else { return; }
	
	notify undef, $title, $text;
}
Irssi::signal_add_last("dcc request", "dcc_req");

sub dcc_finished_receive {
	my ($dcc) = @_;
	my ($title, $text);
	if ($dcc->{type} eq "GET") {	
		$title = "File received";
		$text = $dcc->{arg}." (from ".$dcc->{nick}.")";
	}
	elsif ($dcc->{type} eq "SEND") {
		$title = "File sent";
		$text = $dcc->{arg}." (from ".$dcc->{nick}.")";
	}
	else { return; }
	
	notify undef, $title, $text;
}
Irssi::signal_add_last("dcc closed", "dcc_finished_receive");

# Fuck DCC errors
