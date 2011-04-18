# vim: ft=perl
use strict;
use Irssi;
use vars qw($VERSION %IRSSI);

$VERSION = "0.3";
%IRSSI = (
	authors     => 'Mantas Mikulėnas',
	contact     => 'grawity@gmail.com',
	name        => 'quakenet-auth.pl',
	description => "Sends the server password to QuakeNet's Q (for those who dislike autosendcmds)",
	license     => 'WTFPL v2 <http://sam.zoy.org/wtfpl/>',
	url         => 'http://purl.net/net/grawity/irssi.html',
);

Irssi::signal_add_last "event 001" => sub {
	my ($server, $evargs, $srcnick, $srcaddr) = @_;
	return unless $srcnick =~ /\.quakenet\.org$/;

	my $user = $server->{username};
	my $pass = $server->{password};
	return if $pass eq "";

	$server->print("", "Authenticating to Q as $user");
	$server->send_message('Q@cserve.quakenet.org', "auth $user $pass", 1);
};
