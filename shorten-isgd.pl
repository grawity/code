#!/usr/bin/perl
# simple URL shortener, using is.gd

# Usage: shorten <url>

use warnings;
use strict;
use URI::Escape qw( uri_escape );
use LWP::UserAgent;

sub msg_usage() {
	print STDERR "Usage: shorten <url>\n";
	return 1;
}

sub isgd($) {
	my ($longurl) = @_;
	
	my $apiurl = "http://is.gd/api.php?longurl=".uri_escape($longurl);

	my $req = new LWP::UserAgent;
	my $resp = $req->get($apiurl);

	chomp(my $content = $resp->decoded_content);
	if ($resp->code == "200" and $content =~ m!^http://!) {
		return $content;
	}
	else {
		print STDERR "[is.gd] $content\n";
		return undef;
	}
}

my $longurl = shift @ARGV;
exit msg_usage if !defined $longurl;

my $shorturl = isgd($longurl);

if (defined $shorturl) {
	print "$shorturl\n";
}
else {
	exit 1;
}
