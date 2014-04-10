package Nullroute::Lib;
use base "Exporter";
use File::Basename;

our @EXPORT = qw(
	_debug
	_info
	_warn
	_err
	_die
	forked
	readfile
	uniq
);

$::arg0 //= basename($0);

$::debug = int $ENV{DEBUG};
$::arg0prefix = $ENV{LVL}++ || $ENV{DEBUG};

$::warnings = 0;
$::errors = 0;

sub _msg {
	my $prefix = shift;
	my $msg = shift;
	my $color = (-t 2) ? shift : "";
	my $reset = (-t 2) ? "\e[m" : "";
	my $name = $::arg0 . ($::debug ? "[$$]" : "");
	my $nameprefix = $::arg0prefix ? "$name: " : "";

	if ($prefix eq "debug") {
		my @frame = caller(2); # stack frame below _debug()
		$frame[3] //= "main";
		$frame[3] =~ s/^main:://;
		#$msg = $frame[1].":".$frame[2]." (".$frame[3].") ".$msg;
		#$msg = "(".$frame[3].") ".$msg;
		$prefix = $prefix." (".$frame[3].")";
	}

	warn "${nameprefix}${color}${prefix}:${reset} ${msg}\n";
}

sub _debug { _msg("debug", shift, "\e[36m") if $::debug; }

sub _info  { _msg("info", shift, "\e[1;34m") if $::debug; }

sub _warn  { _msg("warning", shift, "\e[1;33m"); ++$::warnings; }

sub _err   { _msg("error", shift, "\e[1;31m"); ++$::errors; }

sub _die   { _err(shift); exit 1; }

sub forked (&) { fork || exit shift->(); }

sub readfile {
	my ($file) = @_;

	open(my $fh, "<", $file) or die "$!";
	grep {chomp} my @lines = <$fh>;
	close($fh);
	wantarray ? @lines : shift @lines;
}

sub uniq (@) { my %seen; grep {!$seen{$_}++} @_; }

1;
