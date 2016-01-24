#!/usr/bin/env perl
use warnings;
use strict;
use Net::DNS;
use Getopt::Long qw(:config bundling no_ignore_case);

my %opt;

sub color {
	my ($str) = @_;

	return $str;
}

sub go {
	my ($arg, $depth, $skip, $visited) = @_;
	
	$depth //= 0;
	$skip //= [];
	$visited //= [];

	print "   "x$depth.color($arg)." = ";

}

%opt = (
	color => 1,
);

GetOptions(
	"color!" => \$opt{color},
) or die;

for my $arg (@ARGV) {
	go($arg);
}
