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
	my ($msg, $prefix, $pfx_color, %opt) = @_;

	my $color = (-t 2) ? $pfx_color : "";
	my $reset = (-t 2) ? "\e[m" : "";
	my $do_arg0 = $::arg0prefix // $::nested || $::debug;
	my $name = $do_arg0 ? $::arg0 . ($::debug ? "[$$]" : "") . ": " : "";

	if ($prefix eq "debug" || $::debug >= 2) {
		my $skip = ($opt{skip} || 0) + 1;
		my $func;
		do {
			my @frame = caller(++$skip);
			$func = $frame[3] // "main";
		} while ($func =~ /::__ANON__$/);
		$func =~ s/^main:://;
		$prefix .= " ($func)";
	}
	elsif ($prefix eq "usage" && !$::debug && $seen_usage++) {
		$prefix = "   or";
	}

	if ($pre_output) { $pre_output->($msg, $prefix, \*STDERR); }

	warn "${name}${color}${prefix}:${reset} ${msg}\n";

	if ($post_output) { $post_output->($msg, $prefix, \*STDERR); }
}

sub _fmsg {
	goto &_msg if $::debug;

	my ($msg, $prefix, $pfx_color, $fmt_prefix, $fmt_color) = @_;

	my $color = (-t 1) ? $fmt_color : "";
	my $reset = (-t 1) ? "\e[m" : "";
	my $do_arg0 = $::arg0prefix // $::nested || $::debug;
	my $name = $do_arg0 ? $::arg0 . ($::debug ? "[$$]" : "") . ": " : "";

	if ($pre_output) { $pre_output->($msg, $prefix, \*STDOUT); }

	if (length $fmt_prefix) {
		print "${name}${color}${fmt_prefix}${reset} ${msg}\n";
	} else {
		print "${name}${msg}\n";
	}

	if ($post_output) { $post_output->($msg, $prefix, \*STDOUT); }
}

sub _say {
	my ($msg) = @_;

	if ($pre_output) { $pre_output->($msg, "", \*STDOUT); }

	print "${msg}\n";

	if ($post_output) { $post_output->($msg, "", \*STDOUT); }
}

sub _debug  { _msg(shift, "debug", "\e[36m", @_) if $::debug; }

sub _info   { _fmsg(shift, "info", "\e[1;34m", "", ""); }

sub _log    { _fmsg(shift, "log", "\e[1;32m", "--", "\e[32m"); }

sub _notice { _msg(shift, "notice", "\e[1;35m"); }

sub _warn   { _msg(shift, "warning", "\e[1;33m"); ++$::warnings; }

sub _err    { _msg(shift, "error", "\e[1;31m"); ! ++$::errors; }

sub _die    { _msg(shift, "error", "\e[1;31m"); exit int(shift // 1); }

sub _usage  { _msg($::arg0." ".shift, "usage", ""); }

sub _exit   { exit ($::errors > 0); }

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
