#!/usr/bin/perl
# simple URL shortener, using bit.ly

# Usage: shorten <url>

# The API key will be taken from ~/.netrc entry for api.bit.ly
# See manpage of ftp(1) for details.

use warnings;
use strict;
use Net::Netrc;
use URI::Escape qw(uri_escape);
use LWP::Simple;
use XML::Simple;

sub msg_usage() {
	print STDERR "Usage: shorten [-S] [-s service] <url>\n";
	return 1;
}

sub bitly($) {
	my ($longurl) = @_;

	my %args = (
		longUrl => $longurl,
		version => "2.0.1",
		format => "xml",
	);

	my $netrc = Net::Netrc->lookup("api.bit.ly");
	if (defined $netrc->{machine} and defined $netrc->{login} and defined $netrc->{account}) {
		$args{login} = $netrc->{login};
		$args{apiKey} = $netrc->{account};
	}
	else {
		print STDERR "login/account for api.bit.ly not found in ~/.netrc\n";
		return undef;
	}

	my $args = join "&", map { $_ . "=" . uri_escape($args{$_}) } keys %args;
	my $apiurl = "http://api.bit.ly/shorten?$args";

	my $resp = LWP::Simple::get($apiurl);
	$resp = XMLin($resp);

	if ($resp->{statusCode} eq "OK") {
		return $resp->{results}->{nodeKeyVal}->{shortUrl};
	}
	else {
		print STDERR "[bit.ly] ".$resp->{errorMessage}."\n";
		return undef;
	}
}

my $longurl = shift @ARGV;
exit msg_usage if !defined $longurl;

my $shorturl = bitly($longurl);

if (defined $shorturl) {
	print "$shorturl\n";
}
else {
	exit 1;
}
