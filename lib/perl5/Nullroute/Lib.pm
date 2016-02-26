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
	_log2
	_notice
	_warn
	_err
	_die
	_usage
	_exit
	forked
	interval
	randpw
	randstr
	readfile
	trim_inplace
	trim
	uniq
	url_decode
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
my $ext_debug = 0;

sub __extdebug_get_path {
	if (defined $ENV{XDG_RUNTIME_DIR}) {
		return $ENV{XDG_RUNTIME_DIR}."/lib.debug";
	} else {
		return "/dev/shm/lib.debug-$<";
	}
}

sub __extdebug_toggle {
	my ($enable) = @_;

	if ($enable) {
		system("touch", __extdebug_get_path());
	} else {
		system("rm", "-f", __extdebug_get_path());
	}
}

sub __extdebug_check {
	if (-e __extdebug_get_path()) {
		if (!$::debug) {
			$::debug = $ext_debug = 1;
		}
	} else {
		if ($ext_debug) {
			$::debug = $ext_debug = 0;
		}
	}
}

sub _msg {
	my ($io, $log_prefix, $log_color, $msg, %opt) = @_;

	__extdebug_check();

	return if $::debug < ($opt{min_debug} // 0);

	my @output = ();
	my $do_arg0 = $::arg0prefix // $::nested || $::debug;
	my $do_func = $::debug >= 2 || $log_prefix eq "debug";

	my $prefix;
	my $color;
	my $reset = "\e[m";

	if ($do_arg0) {
		push @output, $::arg0, $::debug ? "[$$]" : (), ": ";
	}

	if (!$::debug) {
		$prefix = $opt{fmt_prefix};
		$color = $opt{fmt_color};
	}
	if (!defined $prefix) {
		$prefix = $log_prefix . ":";
		$color = $log_color;
	}
	if (!$::debug && $prefix eq "usage") {
		$prefix = "   or" if $seen_usage++;
	}

	push @output,
		(-t $io && defined $color) ? ($color) : (),
		$prefix,
		(-t $io && defined $color) ? ($reset) : (),
		" ";

	if ($do_func) {
		my $skip = ($opt{skip} || 0) + 1;
		my $func = "main";
		do {
			my @frame = caller(++$skip);
			$func = $frame[3] // "main";
		} while $func =~ /::__ANON__$/;
		$func =~ s/^main:://;
		push @output,
			(-t $io) ? ("\e[38;5;60m") : (),
			"($func)",
			(-t $io) ? ($reset) : (),
			" ";
	}

	push @output,
		(-t $io && defined $opt{msg_color}) ? ($opt{msg_color}) : (),
		$msg,
		(-t $io && defined $opt{msg_color}) ? ($reset) : (),
		"\n";

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

sub _debug  { _msg(*STDERR, "debug", "\e[36m", shift,
		min_debug => 1,
		@_); }

sub _info   { _msg(*STDERR, "info", "\e[1;34m", shift,
		fmt_prefix => "+",
		fmt_color => "\e[34m",
		@_); }

sub _log    { _msg(*STDERR, "log", "\e[1;32m", shift,
		fmt_prefix => "~",
		fmt_color => "\e[32m",
		@_); }

sub _log2   { _msg(*STDERR, "log2", "\e[1;35m", shift,
		fmt_prefix => "==",
		fmt_color => "\e[35m",
		msg_color => "\e[1m",
		@_); }

sub _notice { _msg(*STDERR, "notice", "\e[1;35m", shift,
		fmt_prefix => "notice:",
		fmt_color => "\e[38;5;13m",
		@_); }

sub _warn {
	_msg(*STDERR, "warning", "\e[1;33m", @_);
	return ++$::warnings;
}

sub _err {
	_msg(*STDERR, "error", "\e[1;31m", @_);
	return !++$::errors;
}

sub _die {
	$post_output = undef;
	_msg(*STDERR, "error", "\e[1;31m", shift);
	if ($::debug > 1) {
		use Carp;
		Carp::confess("fatal error");
	}
	exit int(shift // 1);
}

sub _usage {
	_msg(*STDOUT, "usage", "", $::arg0." ".shift);
};

sub _exit { exit ($::errors > 0); }

sub forked (&) { fork || exit shift->(); }

sub interval {
	my ($end, $start) = @_;
	my ($dif, $s, $m, $h, $d);

	$start //= time;
	$d = abs($end - $start);
	$d -= $s = $d % 60; $d /= 60;
	$d -= $m = $d % 60; $d /= 60;
	$d -= $h = $d % 24; $d /= 24;
	$d += 0;

	_debug("d = $d, h = $h, m = $m");

	if ($d > 0)	{ "${d}d ${h}h" }
	elsif ($h > 0)	{ "${h}h ${m}m" }
	elsif ($m > 0)	{ "${m} min" }
	else		{ "${s} sec" }
}

sub randpw {
	my ($len) = @_;
	$len //= 12;

	my @chars = qw(A B C D E F G H J K L M N P Q R S T U V X Z
	               a b c d e f g h i j k m n o p q r s t u v x z
		       2 3 4 6 7 8 9);
	join "", map {$chars[int rand @chars]} 1..$len;
}

sub randstr {
	my ($len) = @_;
	$len //= 12;

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

sub trim_inplace {
	map {s/^\s+//; s/\s+$//} @_;

	return wantarray ? @_ : $_[0];
}

sub trim {
	my (@args) = @_;

	return trim_inplace(@args);
}

sub uniq (@) { my %seen; grep {!$seen{$_}++} @_; }

sub url_decode {
	my ($str) = @_;

	$str =~ s/%([A-Fa-f0-9]{2})/pack('C', hex($1))/seg;
	utf8::decode($str);
	return $str;
}

sub xml_escape {
	my ($str) = @_;

	my %entities = qw(& amp < lt > gt " quot);
	$str =~ s/[&<>"]/\&$entities{${^MATCH}};/gp;
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
