#!perl
use warnings;
use strict;
use vars qw($VERSION %IRSSI);
use Irssi;

$VERSION = "1";
%IRSSI = (
	name		=> 'unmangle_actions.pl',
	description	=> 'Converts incoming "/me ..." messages to actions',
	authors		=> 'Mantas Mikulėnas <grawity@gmail.com>',
	url		=> 'http://nullroute.eu.org/~grawity/irssi.html',
	license		=> 'WTFPL v2 <http://sam.zoy.org/wtfpl/>',
);

Irssi::signal_add("message private", sub {
	my ($server, $msg, $nick, $addr) = @_;
	if ($msg =~ m|^/me (.+)|) {
		Irssi::signal_stop;
		Irssi::signal_emit("message irc action",
			$server, $1, $nick, $addr, $server->{nick});
	}
});
