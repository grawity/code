#!/usr/bin/env perl
use strict;
use Getopt::Long;

sub msg_usage {
	print STDERR "Usage: settermtitle [-e] <title>\n";
	return 2;
}

my $ESC = "\e";
my $ST = "\e\\";
my $BEL = "\007";

sub titlestring {
	$_ = $ENV{TERM} // "dumb";
	/^screen/
		and return "${ESC}k%s${ST}";
	(/^[xkE]term/ or /^rxvt/ or /^cygwin$/)
		and return "${ESC}];%s${BEL}";
	/^vt300/
		and return "${ESC}]21;%s${ST}";
}

GetOptions(
	'e|escape' => sub {
		$ESC = "\\e";
		$ST = "\\e\\\\";
		$BEL = "\\007";
		},
);

my $title = shift;
exit msg_usage() if not defined $title;

printf titlestring, $title;
