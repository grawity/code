package Nullroute::Term;
use base "Exporter";
use feature qw(state);
use warnings;
use strict;
use POSIX qw(ceil);

our @EXPORT = qw(
	status
);

if (eval {require Text::CharWidth}) {
	Text::CharWidth->import("mbswidth");
} else {
	sub mbswidth { length shift; }
}

my $width;

sub status {
	state $lines = 0;
	my ($msg, $fmt) = @_;
	my $out = "";
	$out .= "\e[".($lines-1)."A" if $lines > 1; # cursor up
	$out .= "\e[1G"; # cursor to column 1
	$out .= "\e[0J"; # erase below
	$out .= sprintf($fmt // "%s", $msg);
	$lines = ceil(mbswidth($msg) / $width);
	print $out;
}

1;
