#!/usr/bin/perl -w
use Getopt::Std;
my %opts; getopts('dr', \%opts);
while (<STDIN>) {
	chomp unless $opts{r};
	if ($opts{d}) {
		s/\%([A-Fa-f0-9]{2})/pack('C', hex($1))/seg;
	}
	else {
		s/([^A-Za-z0-9_.!~*'()-])/sprintf("%%%02X", ord($1))/seg;
	}
	print;
	print "\n" unless $opts{r};
}
