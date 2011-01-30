#!/usr/bin/env perl
# Not an Irssi script; just a code snippet.

sub lci ($$) {
	my ($s, $map) = @_;
	if ($map eq 'rfc1459') { $s =~ tr/\[\\\]/{|}/; }
	if ($map eq 'rfc2812') { $s =~ tr/\[\\\]^/{|}~/; }
	return lc $s;
}

sub uci ($$) {
	my ($s, $map) = @_;
	if ($map eq 'rfc1459') { $s =~ tr/\{\|\}/[\\]/; }
	if ($map eq 'rfc2812') { $s =~ tr/\{\|\}~/[\\]^/; }
	return uc $s;
}

# Compare two nicknames on a given server
sub nick_compare ($$$) {
	my ($server, $a, $b) = @_;
	my $casemap = $server->isupport("CASEMAPPING") // "rfc1459";
	return lci $a, $casemap cmp lci $b, $casemap;
}
