use warnings;
use strict;
use Irssi;
use vars qw($VERSION %IRSSI);

my %authinfo = (
	# make sure you have the correct server tag. "freenode" != "freenode2"
	freenode => [ "grawity", "ubersekritpassw3rd" ],
);

$VERSION = "1.1";
%IRSSI = (
	authors     => "Mantas Mikulėnas",
	contact     => 'grawity@gmail.com',
	name        => 'auth_atheme_plain',
	description => 'Automatic identification to Atheme NickServ.',
	license     => 'WTFPL v2 <http://sam.zoy.org/wtfpl/>',
	url         => 'http://purl.oclc.org/NET/grawity/irssi.html',
);

Irssi::signal_add_first "message irc notice" => sub {
	my ($server, $msg, $nick, $address, $target) = @_;

	return unless lc($nick) eq "nickserv";

	if ($msg =~ /^This nickname is registered/i) {
		my $tag = lc $server->{tag};
		return unless defined $authinfo{$tag};
		my ($user, $pass) = @{$authinfo{$tag}};
		$server->print("", "Authenticating to NickServ as %9$user%9");
		$server->send_message($nick, "identify $user $pass", 1);
	}
};
