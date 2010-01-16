#!/usr/bin/perl
# simple URL shortener, using is.gd
# Usage: shorten <url>
use warnings;
use strict;
use URI::Escape qw( uri_escape );
use LWP::UserAgent;

sub msg_usage() {
	print STDERR "Usage: shorten <url>\n";
	return 2;
}

my $longurl = shift @ARGV;
exit msg_usage if !defined $longurl;

my $req = new LWP::UserAgent;
my $resp = $req->get("http://is.gd/api.php?longurl=".uri_escape($longurl));

chomp(my $content = $resp->decoded_content);
if ($resp->code == "200" and $content =~ m!^http://!) {
	print "$content\n";
}
else {
	print STDERR "[is.gd] $content\n";
	exit 1;
}
