#!perl
use warnings;
use strict;
use vars qw($VERSION %IRSSI);
use Irssi;

# BUGS: Applies to /all/ queries, not just OTR'd (as originally intended).

$VERSION = "1";
%IRSSI = (
	name		=> 'mangle_actions.pl',
	description	=> 'Converts outgoing actions to "/me ..." messages',
	authors		=> 'Mantas Mikulėnas <grawity@gmail.com>',
	url		=> 'http://nullroute.eu.org/~grawity/irssi.html',
	license		=> 'WTFPL v2 <http://sam.zoy.org/wtfpl/>',
);

Irssi::signal_add("send command", sub {
	my ($cmdline, $server, $witem) = @_;
	if ($cmdline =~ m|^/me (.*)|i) {
		Irssi::signal_stop;
		$witem->command("/say $cmdline");
	}
});

Irssi::signal_add("message own_private", sub {
	my ($server, $msg, $target, $orig_target) = @_;
	if ($msg =~ m|^/me (.+)|) {
		Irssi::signal_stop;
		Irssi::signal_emit("message irc own_action",
			$server, $1, $target);
	}
});
