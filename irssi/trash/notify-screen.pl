use strict;
use vars qw($VERSION %IRSSI);

use Irssi;
use POSIX;

$VERSION = "0.1";
%IRSSI = (
	name        => 'notify-screen',
	description => 'Notifies you using ANSI Global Message (useful in screen)',
	authors     => 'Mantas Mikulėnas',
	contact     => 'grawity@gmail.com',
	license     => 'WTFPL v2 <http://sam.zoy.org/wtfpl/>',
);

Irssi::signal_add "print text" => sub {
	my ($dest, $text, $stripped) = @_;
	return unless $dest->{level} & Irssi::level2bits("hilights");

	my $msg = sprintf "[%s] %s", $dest->{target}, $stripped;
	if (open my $ttyh, ">>", POSIX::ctermid) {
		print $ttyh "\e!$msg\e\\";
		close $ttyh;
	} else {
		warn $!;
	}
};
