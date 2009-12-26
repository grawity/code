#!/usr/bin/perl
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

sub send {
	my ($dest, $text, $stripped) = @_;
	return unless ($dest->{level} & MSGLEVEL_HILIGHT)
		or ($dest->{level} & MSGLEVEL_MSGS);

	$stripped =~ m/^<(.*?)> (.*)$/;
	
	my $nick = $1;
	my $message = $2;
	
	# remove the "unidentified" question mark
	$nick =~ s/\?$//;
	
	my $msg = "irssi\nnotification-message-IM\n$nick\n$message\n";

	my $dest = Irssi::settings_get_str("notify_host");
	$dest =~ /^(.+):([0-9]{1,5})$/;
	my ($dest_host, $dest_port) = ($1, $2);

	socket(SOCK, PF_INET, SOCK_DGRAM, getprotobyname("udp"));
	my $rcpt = sockaddr_in($dest_port, inet_aton($dest_host));
	send(SOCK, $msg, 0, $rcpt);
}

Irssi::settings_add_str("libnotify", "notify_host", "localhost:22754");

Irssi::signal_add("print text", "send");
