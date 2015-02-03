use strict;
use utf8;
use vars qw($VERSION %IRSSI);
use Irssi;

$VERSION = '0.3';
%IRSSI = (
	name		=> 'spacefail',
	description	=> 'Warns you if you have extra spaces before /command',
	contact		=> 'Mantas Mikulėnas <grawity@gmail.com>',
	license		=> 'WTFPL v2 <http://sam.zoy.org/wtfpl/>',
);

Irssi::signal_add("send text" => sub {
	my ($line, $server, $witem) = @_;

	$witem //= Irssi::active_win;

	if ($line =~ m|^\s+/(\w+)|) {
		$witem->command("scrollback end");
		$witem->print("Stopped command \002/$1\002 from being sent to channel.",
			MSGLEVEL_CLIENTERROR);
		Irssi::signal_stop;
	}
	elsif ($line eq 'ls') {
		$witem->command("names");
		Irssi::signal_stop;
	}
	elsif ($line =~ /^[:;]w?q$/) {
		$witem->print("This is not Vi.");
		Irssi::signal_stop;
	}
});
