# vim: ft=perl
use strict;
use Irssi;
use vars qw($VERSION %IRSSI);

$VERSION = "1.0";
%IRSSI = (
	authors     => 'Mantas Mikulėnas',
	contact     => 'grawity@gmail.com',
	name        => 'autoghost.pl',
	description => "Automatically ghosts your primary nick",
	license     => 'WTFPL v2 <http://sam.zoy.org/wtfpl/>',
	url         => 'http://purl.net/net/grawity/irssi.html',
);

Irssi::signal_add_last "event 001" => sub {
	my ($server, $evargs, $srcnick, $srcaddr) = @_;
	return if $server->{nick} eq $server->{wanted_nick};
	$server->send_message("NickServ", "ghost ".$server->{wanted_nick}, 1);
};

# automatically /nicks to a nickname you just ghosted.
Irssi::signal_add_last "message irc notice" => sub {
	my ($server, $msg, $nick, $addr, $target) = @_;
	return unless $nick eq 'NickServ' and $msg =~ /.(.+?). has been ghosted.$/;
	my $wantnick = $1;
	$server->send_raw("nick $wantnick");
}
