#!/usr/bin/env perl
use warnings;
use strict;

my @data = ();

open my $fh, "<", "$ENV{HOME}/.muttaliases";
while (<$fh>) {
	chomp;
	next unless /^alias (.+?) (?:(.+) )?<(.+?)>$/;

	push @data, {
		nick => $1,
		name => $2,
		email => $3,
	};
}

@data;
