#!perl
package Nullroute::Lib;
use base "Exporter";
use File::Basename;

our @EXPORT = qw(
	_warn
	_err
	_die
	forked
	readfile
	uniq
);

$::arg0 //= basename($0);

$::arg0prefix = $ENV{LVL}++ || $ENV{DEBUG};

sub _msg {
	my $prefix = shift;
	my $msg = shift;
	my $color = (-t 2) ? shift : "";
	my $reset = (-t 2) ? "\e[m" : "";
	my $name = $::arg0prefix ? "$::arg0: " : "";

	warn "${name}${color}${prefix}:${reset} ${msg}\n";
}

sub _warn { _msg("warning", shift, "\e[1;33m"); }

sub _err  { _msg("error", shift, "\e[1;31m"); }

sub _die  { _err(shift); exit 1; }

sub forked(&) { fork || exit shift->(); }

sub readfile {
	my ($file) = @_;

	open(my $fh, "<", $file) or die "$!";
	grep {chomp} my @lines = <$fh>;
	close($fh);
	wantarray ? @lines : shift @lines;
}

sub uniq { my %seen; grep {!$seen{$_}++} @_; }

1;
