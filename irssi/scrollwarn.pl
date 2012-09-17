use strict;
use utf8;
use vars qw($VERSION %IRSSI);
use Irssi;

$VERSION = '0.3';
%IRSSI = (
	name		=> 'scrollwarn',
	description	=> 'Warns you if you were scrolled up when sending a message.',
	contact		=> 'Mantas Mikulėnas <grawity@gmail.com>',
	license		=> 'WTFPL v2 <http://sam.zoy.org/wtfpl/>',
);

sub check {
	my ($win) = @_;
	my $view = $win->view;
	if (!$view->{bottom}) {
		my $lines = $view->{ypos} - $view->{height};
		$win->command("scrollback end");
		$win->print("You were scrolled up by $lines lines. Message not sent.",
			MSGLEVEL_CLIENTERROR);
		return 0;
	} else {
		return 1;
	}
}

Irssi::signal_add("send text" => sub {
	my ($line, $server, $witem) = @_;
	if (!check(Irssi::active_win)) {
		Irssi::signal_stop;
	}
});
