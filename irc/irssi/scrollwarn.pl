use strict;
use utf8;
use vars qw($VERSION %IRSSI);
use Irssi;
use Irssi::TextUI;

$VERSION = '0.4';
%IRSSI = (
	name		=> 'scrollwarn',
	description	=> 'Warns you if you were scrolled up when sending a message.',
	contact		=> 'Mantas Mikulėnas <grawity@gmail.com>',
	license		=> 'MIT (Expat) <https://spdx.org/licenses/MIT>',
);

Irssi::signal_add("send text" => sub {
	my ($line, $server, $witem) = @_;

	my $win = Irssi::active_win;
	my $view = $win->view;
	if (!$view->{bottom}) {
		my $lines = $view->{ypos} - $view->{height};
		$win->command("scrollback end");
		$win->print("You were scrolled up by $lines lines. Message not sent.",
			MSGLEVEL_CLIENTERROR);
		Irssi::signal_stop;
	}
});
