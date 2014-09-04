package Nullroute::Lib;
use base "Exporter";
use warnings;
use strict;
use Carp;
use File::Basename;
use constant {
	true => 1,
	false => 0,
};

our @EXPORT = qw(
	true
	false
	_say
	_debug
	_info
	_log
	_notice
	_warn
	_err
	_die
	_usage
	_exit
	forked
	interval
	randstr
	readfile
	trim
	uniq
	xml_escape
);

$::arg0 //= basename($0);

$::nested = $ENV{LVL}++;
$::debug = do { no warnings; int $ENV{DEBUG} };

$::warnings = 0;
$::errors = 0;

our $pre_output = undef;
our $post_output = undef;

my $seen_usage = 0;

sub _msg {
	my ($io, $log_prefix, $log_color,
		$fmt_prefix, $fmt_color,
		$min_debug, $msg, %opt) = @_;

	return if $::debug < $min_debug;

	my @output = ();
	my $do_arg0 = $::arg0prefix // $::nested || $::debug;
	my $do_func = $::debug >= 2 || $log_prefix eq "debug";

	my $prefix;
	my $color = (-t $io) ? $log_color : "";
	my $reset = (-t $io) ? "\e[m"     : "";

	if ($do_arg0) {
		push @output, $::arg0, $::debug ? "[$$]" : (), ": ";
	}

	if ($do_func) {
		my $skip = ($opt{skip} || 0) + 1;
		my $func = "main";
		do {
			my @frame = caller(++$skip);
			$func = $frame[3] // "main";
		} while $func =~ /::__ANON__$/;
		$func =~ s/^main:://;
		push @output, "(", $func, ") ";
	}

	if (!$::debug) {
		$prefix = $fmt_prefix;
	}
	if (!defined $prefix) {
		$prefix = $log_prefix . ":";
	}
	if (!$::debug && $prefix eq "usage") {
		$prefix = "   or" if $seen_usage++;
	}

	push @output, $color, $prefix, $reset, " ";
	push @output, $msg, "\n";

	if ($pre_output) { $pre_output->($msg, $prefix, $io); }

	print $io @output;

	if ($post_output) { $post_output->($msg, $prefix, $io); }
}

sub _say {
	my ($msg) = @_;

	if ($pre_output) { $pre_output->($msg, "", \*STDOUT); }

	print "$msg\n";

	if ($post_output) { $post_output->($msg, "", \*STDOUT); }
}

sub _debug  { _msg(*STDERR, "debug", "\e[36m", undef, undef, 1, @_); }

sub _info   { _msg(*STDOUT, "info", "\e[1;34m", undef, undef, 1, @_); }

sub _log    { _msg(*STDOUT, "log", "\e[1;32m", "--", "\e[32m", 0, @_); }

sub _notice { _msg(*STDERR, "notice", "\e[1;35m", undef, undef, 0, @_); }

sub _warn {
	_msg(*STDERR, "warning", "\e[1;33m", undef, undef, 0, @_);
	return ++$::warnings;
}

sub _err {
	_msg(*STDERR, "error", "\e[1;31m", undef, undef, 0, @_);
	return !++$::errors;
}

sub _die {
	$post_output = undef;
	_msg(*STDERR, "error", "\e[1;31m", undef, undef, 0, shift);
	exit int(shift // 1);
}

sub _usage {
	_msg(*STDOUT, "usage", "", undef, undef, 0, $::arg0." ".shift);
};

sub _exit { exit ($::errors > 0); }

sub forked (&) { fork || exit shift->(); }

sub interval {
	my ($end, $start) = @_;
	my ($dif, $s, $m, $h, $d);

	$start //= time;
	$dif = $end - $start;
	$dif -= $s = $dif % 60; $dif /= 60;
	$dif -= $m = $dif % 60; $dif /= 60;
	$dif -= $h = $dif % 24; $dif /= 24;
	$d = $dif + 0;

	if ($d > 1)	{ "${d}d ${h}h" }
	elsif ($h > 0)	{ "${h}h ${m}m" }
	elsif ($m > 0)	{ "${m} mins" }
	else		{ "${s} secs" }
}

sub randstr {
	my $len = shift // 12;

	my @chars = ('A'..'Z', 'a'..'z', '0'..'9');
	join "", map {$chars[int rand @chars]} 1..$len;
}

sub readfile {
	my ($file) = @_;

	open(my $fh, "<", $file) or croak "$!";
	grep {chomp} my @lines = <$fh>;
	close($fh);
	wantarray ? @lines : shift @lines;
}

sub trim { map {s/^\s+//; s/\s+$//; $_} @_; }

sub uniq (@) { my %seen; grep {!$seen{$_}++} @_; }

sub xml_escape {
	my $str = shift;

	my %chars = ('&' => "amp", '<' => "lt", '>' => "gt", '"' => "quot");
	$str =~ s/[&<>"]/\&$chars{${^MATCH}};/gp;
	return $str;
}

$SIG{USR2} = sub {
	if ($::debug) {
		_debug("got SIGUSR2, disabling debug mode");
		$::debug = 0;
	} else {
		$::debug = 1;
		_debug("got SIGUSR1, enabling debug mode");
	}
};

_debug("[$ENV{LVL}] lib.pm loaded by $0") if $::debug >= 2;

1;
