#!/usr/bin/perl -w
use strict;
use Getopt::Long;

sub msg_usage {
	print STDERR "Usage: settermtitle [-e] [-a|-x] <title>\n";
	return 2;
}

my $ESC = "\e", $ST_ANSI = "\e\\", $ST_XTERM = "\007";

my $ST = \$ST_ANSI;

sub titlestring {
	$_ = $ENV{TERM} // "dumb";
	/^screen/
		and return "${ESC}k%s${$ST}";
	(/^[xkE]term/ or /^rxvt/)
		and return "${ESC}]0;%s${$ST}";
	/^vt300/
		and return "${ESC}]21;%s${$ST}";
}

GetOptions(
	'e|escape' => sub {
		$ESC = "\\e";
		$ST_ANSI = "\\e\\\\";
		$ST_XTERM = "\\007";
		},
	'a|ansi-st' => sub { $ST = \$ST_ANSI },
	'x|xterm-st' => sub { $ST = \$ST_XTERM },
);

my $title = shift;
exit msg_usage() if not defined $title;

printf titlestring, $title;
