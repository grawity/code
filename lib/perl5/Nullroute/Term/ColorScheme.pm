package Nullroute::Term::ColorScheme;
use base "Exporter";
use warnings;
use strict;
use Nullroute::Dir qw(xdg_config);
use Nullroute::Lib qw(_debug);

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

sub find_config_files {
	# Uses the same algorithm as colors_readdir() in util-linux:lib/colors.c
	my ($prog, $term) = @_;
	my @dirs = map {"$_/terminal-colors.d"} xdg_config(), "/etc";
	for my $dir (@dirs) {
		next unless (-d $dir);
		_debug("searching in '$dir'");
		my @files;
		if (opendir(my $dh, $dir)) {
			@files = readdir($dh);
			closedir($dh);
		} else {
			_debug("cannot open directory '$dir': $!");
			next;
		}
		my $scheme;
		my %scores;
		for my $file (@files) {
			my $path = $dir."/".$file;
			next unless (-f $path);
			my ($ident, $type) = $file =~ /
				^
				( \Q$prog\E@\Q$term\E\. | \Q$prog\E\. | @\Q$term\E\. | )
				( enable|disable|scheme )
				$
			/x or next;
			my $score = 1;
			$score += 20 if $ident;
			$score += 10 if $ident =~ /@/;
			$score -= 20 if $ident =~ /^@/;
			_debug("found file: ident='$ident' type='$type' score=$score");
			if (($scores{$type} || 0) < $score) {
				$scores{$type} = $score;
				if ($type eq "scheme") {
					$scheme = $path;
				}
			}
		}
		return ($scheme, %scores);
	}
}

sub parse_seq {
	my ($seq) = @_;
	if ($COLOR_NAMES{$seq}) {
		return $COLOR_NAMES{$seq};
	}
	$seq =~ s/^.*$/\e[$&m/;
	$seq =~ s!\\(.)!$CESCAPE_CHARS{$1} // $&!ge;
	return $seq;
}

sub read_scheme_file {
	my ($path) = @_;
	my %colors;
	if (open(my $fh, "<", $path)) {
		while (<$fh>) {
			if (/^$/ || /^#/) {
				next;
			}
			if (/^(\S+) (\S+)/) {
				$colors{$1} = parse_seq($2);
			}
		}
		close($fh);
	} else {
		_debug("cannot open file '$path': $!");
	}
	return %colors;
}

sub load_color_scheme {
	my ($prog, $mode) = @_;
	my $term = $ENV{TERM} // "";
	my ($scheme, %scores);
	if (!$mode) {
		$mode = ($term ? "auto" : "never");
	}
	if ($mode ne "never") {
		($scheme, %scores) = find_config_files($prog, $term);
		# XXX: this should be moved inside find_config_files()
		if (($scores{disable} || 0) > ($scores{enable} || 0)) {
			_debug("setting mode to 'never' since .disable has higher score");
			$mode = "never";
		}
	}
	_debug("mode='$mode' scheme='$scheme'");
	my %colors;
	if ($mode ne "never" && -f $scheme) {
		%colors = read_scheme_file($scheme);
	}
	return ($mode, %colors);
}

sub setup_color_scheme {
	my ($name, %default) = @_;
	my ($mode, %colors) = load_color_scheme($name);
	for (keys %default) {
		$colors{$_} ||= parse_seq($default{$_});
	}
	if ($mode eq "never") {
		for (keys %colors) {
			$colors{$_} = "";
		}
	}
	return %colors;
}

1;
