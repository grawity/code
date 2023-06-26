package Nullroute::Term::ColorScheme;
use base "Exporter";
use warnings;
use strict;

our @EXPORT = qw(
	setup_color_scheme
);

my %COLOR_NAMES = (
	# Compatible with util-linux:include/color-names.h
	black		=> "\e[30m",
	blink		=> "\e[5m",
	blue		=> "\e[34m",
	bold		=> "\e[1m",
	brown		=> "\e[33m", # /* well, brown */
	cyan		=> "\e[36m",
	darkgray	=> "\e[1;30m",
	gray		=> "\e[37m",
	green		=> "\e[32m",
	halfbright	=> "\e[2m",
	lightblue	=> "\e[1;34m",
	lightcyan	=> "\e[1;36m",
	lightgray	=> "\e[1;37m",
	lightgreen	=> "\e[1;32m",
	lightmagenta	=> "\e[1;35m",
	lightred	=> "\e[1;31m",
	magenta		=> "\e[35m",
	red		=> "\e[31m",
	reset		=> "\e[m",
	reverse		=> "\e[7m",
	#underscore	=> missing in util-linux
	yellow		=> "\e[1;33m",
	#white		=> missing in util-linux
);

my %CESCAPE_CHARS = (
	# Compatible with util-linux:cn_sequence()
	a => "\a",
	b => "\b",
	e => "\e",
	f => "\f",
	n => "\n",
	r => "\r",
	t => "\t",
	v => "\013",
	"\\" => "\\",
	"_" => " ",
	"#" => "#",
	"?" => "?",
);

sub parse_seq {
	my ($seq) = @_;
	if ($COLOR_NAMES{$seq}) {
		return $COLOR_NAMES{$seq};
	}
	$seq =~ s/^.*$/\e[$&m/;
	$seq =~ s!\\(.)!$CESCAPE_CHARS{$1} // $&!ge;
	return $seq;
}

sub setup_color_scheme {
	my ($name, %default) = @_;
	my %colors;
	my $term = $ENV{TERM} // "";
	my $mode = ($term ? "auto" : "never");
	if ($mode eq "never") {
		for (keys %default) {
			$colors{$_} = "";
		}
	} else {
		for (keys %default) {
			$colors{$_} = parse_seq($default{$_});
		}
	}
	return %colors;
}

1;
