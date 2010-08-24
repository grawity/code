#!/usr/bin/perl -w
use strict;
use Getopt::Std;

my %opts;

sub usage() {
	print STDERR "Usage: urlencode [-dr] [string]\n";
	print STDERR "\n";
	print STDERR "    -d    decode\n";
	print STDERR "    -r    do not print ";
}

sub encode() {
	s/\%([A-Fa-f0-9]{2})/pack('C', hex($1))/seg;
}
sub decode() {
	s/([^A-Za-z0-9_.!~*'()-])/sprintf("%%%02X", ord($1))/seg;
}

sub do_things() {
	if ($opts{d}) {
		encode;
	} else {
		decode;
	}
	print;
	print "\n" unless $opts{r};
}

getopts('dr', \%opts);

if (scalar @ARGV) {
	do_things for @ARGV;
} else {
	while (<STDIN>) {
		chomp unless $opts{r};
		do_things;
	}
}
