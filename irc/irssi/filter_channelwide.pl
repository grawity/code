# vim: ft=perl
use warnings;
use strict;
use Irssi;
use vars qw($VERSION %IRSSI);

$VERSION = "1.3";
%IRSSI = (
	name        => 'filter_channelwide',
	description => 'Block channel-wide notices and other junk',
	authors     => 'grawity',
	contact     => 'grawity@gmail.com',
	license     => 'WTFPL v2 <http://sam.zoy.org/wtfpl/>',
	url         => 'http://purl.net/NET/grawity/',
);

Irssi::signal_add_first "message irc notice" => sub {
	my ($server, $msg, $nick, $addr, $target) = @_;

	# Block channel-wide notices
	Irssi::signal_stop() if $server->ischannel($target);
};

Irssi::signal_add_first "ctcp msg" => sub {
	my ($server, $args, $nick, $addr, $target) = @_;

	# Block channel-wide CTCPs
	if ($server->ischannel($target)) {
		Irssi::signal_stop() unless $args =~ /^ACTION /i;
	}
};

# This one might be not even needed - "ctcp msg" might be blocking everything.
Irssi::signal_add_first "dcc request" => sub {
	my ($dccrec, $addr) = @_;

	# Don't ask why did I do this bass-ackwards instead of just using
	# if (foo) { signal_stop(); } like any sane person... Just don't ask.
	do { $dccrec->destroy(); Irssi::signal_stop(); }
		if $dccrec->{server}->ischannel($dccrec->{target});
};
