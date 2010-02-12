# vim: ft=perl
use strict;
use Irssi;
use vars qw($VERSION %IRSSI);

$VERSION = "0.5";
%IRSSI = (
	authors     => 'Mantas Mikulėnas',
	contact     => 'grawity@gmail.com',
	name        => 'webirc.pl',
	description => 'Implements WEBIRC authentication for UnrealIRCd',
	license     => 'WTFPL v2 <http://sam.zoy.org/wtfpl/>',
	url         => 'http://purl.oclc.org/NET/grawity/irssi.html',
);

%auth = (
	cluenet => "youwish",
);

%fakeinfo = (
	cluenet => [ "localhost", "127.0.0.1" ],
);

Irssi::signal_add_last "server connected" => sub {
	my ($server) = @_;
	my $tag = lc $server->{tag};
	if (defined $auth{$tag} and defined $fakeinfo{$tag}) {
		webirc $server, $auth{$tag}, "cgiirc", @{$fakeinfo{$tag}};
	}
}

sub webirc {
	my ($server, $password, $hostname, $ip) = @_;
	$server->print("", "Attempting WEBIRC authentication");
	$server->send_raw_now("WEBIRC $password cgiirc $hostname $ip");
}

