# vim: ft=perl
use warnings;
use strict;
use Irssi;
use vars qw($VERSION %IRSSI);

$VERSION = "1.2.constantly-evolving";
%IRSSI = (
	authors     => 'grawity',
	contact     => 'grawity@gmail.com',
	name        => 'spamfilter',
	description => 'Automatically ignores messages matching certain patterns.',
	license     => 'WTFPL v2 <http://sam.zoy.org/wtfpl/>',
	url         => 'http://purl.oclc.org/NET/grawity/irssi.html',
);

## This is a heavily trimmed down version. It blocks channel-wide
## CTCPs and nothing else. For a full version, see my website.

Irssi::signal_add_first "ctcp msg" => sub {
	my ($server, $args, $nick, $addr, $target) = @_;
	return if $args =~ /^ACTION /i;

	Irssi::signal_stop() if $server->ischannel($target);
};

# This one might be not even needed - I have a feeling that "ctcp msg"
# already blocks everything.
Irssi::signal_add_first "dcc request" => sub {
	my ($dccrec, $addr) = @_;

	# Don't ask why did I do this bass-ackwards instead of just using
	# if (foo) { signal_stop(); } like any sane person... Just don't ask.
	do { $dccrec->destroy(); Irssi::signal_stop(); }
		if $server->ischannel($dccrec->{target});
};

