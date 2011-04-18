#!perl
# Matches are ordered by "host:port" -> "host" -> "chatnet".
# Entries with a matching 'login' are preferred.
use strict;
use utf8;
use vars qw($VERSION %IRSSI);
use warnings;
use Irssi;
use Net::Netrc;

$VERSION = "1.0";
%IRSSI = (
	authors		=> 'Mantas Mikulėnas',
	contact		=> 'grawity@gmail.com',
	name		=> 'netrc.pl',
	description	=> "Looks up the server password in ~/.netrc",
	license		=> 'WTFPL v2 <http://sam.zoy.org/wtfpl/>',
	url		=> 'http://purl.net/net/grawity/irssi.html',
);

sub lookup {
	my ($machine, $login) = @_;
	my $rc = Net::Netrc->lookup($machine, $login);
	return defined $rc->{machine} ? $rc->{password} : undef;
}

Irssi::signal_add_first "server connected" => sub {
	my ($server) = @_;
	return unless $server->{chat_type} eq "IRC";

	my $host = $server->{address};
	my $port = $server->{port};
	my $network = $server->{chatnet};
	my $login = $server->{wanted_nick};

	# This could be ordered better.
	my $pwd =
		lookup($host.":".$port, $login) //
		lookup($host.":".$port) //
		lookup($host, $login) //
		lookup($host) //
		lookup($network, $login) //
		lookup($network) //
		undef;
	
	if (defined $pwd) {
		$server->send_raw_now("PASS :$pwd");
	}
};
