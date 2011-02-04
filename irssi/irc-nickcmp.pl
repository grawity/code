#!/usr/bin/env perl
use strict;
# Not an Irssi script; just a code snippet.

sub lci {
	my ($str, $map) = @_;
	if ($map eq 'rfc1459') { $str =~ tr/\[\\\]/{|}/; }
	if ($map eq 'rfc2812') { $str =~ tr/\[\\\]^/{|}~/; }
	return lc $str;
}

sub uci {
	my ($str, $map) = @_;
	if ($map eq 'rfc1459') { $str =~ tr/\{\|\}/[\\]/; }
	if ($map eq 'rfc2812') { $str =~ tr/\{\|\}~/[\\]^/; }
	return uc $str;
}

# Compare two nicknames on a given server
sub nick_compare {
	my ($server, $a, $b) = @_;
	my $casemap = $server->isupport("CASEMAPPING") // "rfc1459";
	return lci $a, $casemap cmp lci $b, $casemap;
}
