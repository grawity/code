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

my %fmt_attrs = (
	bold => 1,		no_bold => 22,
	dim => 2,		no_dim => 22,
	italic => 3,		no_italic => 23,
	underline => 4,		no_underline => 24,
	blink => 5,		no_blink => 25,
	reverse => 7,		no_reverse => 27,
);

my %fmt_colors = (
	black => 0,
	red => 1,
	green => 2,
	yellow => 3,
	brown => 3,
	blue => 4,
	magenta => 5,
	cyan => 6,
	white => 7,
);

sub parse_fmt_words {
	my (@words) = @_;
	my %fmt;
	my $fg;
	my $bg;
	for (@words) {
		if (exists $words{$_}) {
			$fmt{$_} = 1;
		}
		elsif (/^fg:(\d+)$/) { $fg = int $1; }
		elsif (/^bg:(\d+)$/) { $bg = int $1; }
		elsif (/^fg:(.+)$/ && exists $colors{$1}) { $fg = $colors{$1}; }
		elsif (/^bg:(.+)$/ && exists $colors{$1}) { $bg = $colors{$1}; }
		else {
			warn "unknown '$_'\n";
		}
	}
	my @fmt = sort map {$words{$_}} keys %fmt;
	if (defined $fg) { push @fmt, 38, 5, $fg; }
	if (defined $bg) { push @fmt, 48, 5, $bg; }
	print join(";", @fmt);
	#print "\n";
}

1;
