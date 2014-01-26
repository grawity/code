use strict;
use utf8;
use vars qw($VERSION %IRSSI);
use Irssi;

$VERSION = '0.2';
%IRSSI = (
	name		=> 'spacefail',
	description	=> 'Warns you if you have extra spaces before /command',
	contact		=> 'Mantas Mikulėnas <grawity@gmail.com>',
	license		=> 'WTFPL v2 <http://sam.zoy.org/wtfpl/>',
);

Irssi::signal_add("send text" => sub {
	my ($line, $server, $witem) = @_;
	if ($line =~ m|^\s+/(\w+)|) {
		Irssi::command("scrollback end");
		$witem //= Irssi::active_win;
		$witem->print("Stopped command \002/$1\002 from being sent to channel.",
			MSGLEVEL_CLIENTERROR);
		Irssi::signal_stop;
	}
});
