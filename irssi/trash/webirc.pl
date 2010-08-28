# vim: ft=perl
use strict;
use Irssi;
use vars qw($VERSION %IRSSI);

$VERSION = "0.6";
%IRSSI = (
	name        => 'webirc.pl',
	description => 'Implements WEBIRC authentication for UnrealIRCd',
	license     => 'WTFPL v2 <http://sam.zoy.org/wtfpl/>',
);

my %auth = (
	blahnet => "youwish",
);

my %fakeinfo = (
	blahnet => ["fbi.gov", "127.0.0.1"],
);

sub webirc {
	my ($server, $password, $fake) = @_;
	my ($hostname, $ip) = @$fake;
	$ip =~ s/^:/::/;
	$server->print("", "Setting $hostname as hostname");
	$server->send_raw_now("WEBIRC $password cgiirc $hostname $ip");
}

Irssi::signal_add_last "server connected" => sub {
	my ($server) = @_;
	my $tag = lc $server->{tag};
	if (defined $auth{$tag} and defined $fakeinfo{$tag}) {
		webirc $server, $auth{$tag}, "cgiirc", $fakeinfo{$tag};
	}
}

