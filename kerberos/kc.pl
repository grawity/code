#!/usr/bin/env perl
# kc - Kerberos credential cache juggler
# For cache switching to work, kc.sh must be sourced.
use warnings;
no if $] >= 5.017011, warnings => qw(experimental::smartmatch);
use strict;
use feature qw(say switch);
use English;
use File::Basename;
use File::stat;
use File::Temp qw(tempfile);

my $rundir;
my $ccprefix;
my $runprefix;
my $cccurrent;
my $ccenviron;
my $ccdefault;
my $cccdir;
my $cccprimary;
my @caches;

my $can_switch = 1;
my $use_color = 1;

sub TODO { die "Not yet implemented"; }

sub uniq { my %seen; grep {!$seen{$_}++} @_; }

sub interval {
	my $end = shift;
	my $start = shift // time;
	my ($dif, $s, $m, $h, $d);

	$dif = $end - $start;
	$dif -= $s = $dif % 60; $dif /= 60;
	$dif -= $m = $dif % 60; $dif /= 60;
	$dif -= $h = $dif % 24; $dif /= 24;
	$d = $dif + 0;

	if ($d > 1)	{ "${d}d ${h}h" }
	elsif ($h > 0)	{ "${h}h ${m}m" }
	elsif ($m > 1)	{ "${m} mins" }
	elsif ($s > 45)	{ "a minute" }
	else		{ "${s} secs" }
}

sub read_proc {
	my @argv = @_;
	my $output;

	open(my $proc, "-|", @argv) or die "$!";
	chomp($output = <$proc>);
	close($proc);

	return $output;
}

sub read_file {
	my ($path) = @_;
	my $output;

	open(my $file, "<", $path) or die "$!";
	chomp($output = <$file>);
	close($file);

	return $output;
}

sub enum_ccaches {
	my @ccaches;

	open(my $proc, "-|", "pklist", "-l", "-N") or die "$!";
	push @ccaches, grep {chomp or 1} <$proc>;
	close($proc);

	# traditional

	push @ccaches,	map {"FILE:$_"}
			grep {
				my $st = stat($_);
				-f $_ && $st->uid == $UID
			}
			glob("/tmp/krb5cc*");

	# new

	if (-d "$rundir/krb5cc") {
		push @ccaches,	map {"DIR::$_"}
				glob("$rundir/krb5cc/tkt*");

		push @ccaches,	map {"DIR::$_"}
				glob("$rundir/krb5cc_*/tkt*");
	}

	# Heimdal kcmd

	if (-S "/var/run/.heim_org.h5l.kcm-socket") {
		push @ccaches, "KCM:$UID";
	}

	# kernel keyrings

	my @keys = uniq map {split} grep {chomp or 1}
		   qx(keyctl rlist \@s 2>/dev/null),
		   qx(keyctl rlist \@u 2>/dev/null);
	for my $key (@keys) {
		my $desc = read_proc("keyctl", "rdescribe", $key);
		if ($desc =~ /^keyring;.*?;.*?;.*?;(krb5cc\.*)$/) {
			push @ccaches, "KEYRING:$1";
		}
	}

	@ccaches = uniq sort @ccaches;
			uniq sort @ccaches;

	my $have_current = ($cccurrent ~~ @ccaches);
	my $have_default = ($ccdefault ~~ @ccaches);
	if (!$have_current) {
		push @ccaches, $cccurrent;
	}

	@ccaches = grep {system("pklist", "-q", "-c", $_) == 0} @ccaches;

	return @ccaches;
}

sub expand_ccname {
	my ($name) = @_;
	for ($name) {
		when ("new") {
			my (undef, $path) = tempfile($ccprefix."XXXXXX", OPEN => 0);
			return "FILE:$path";
		}
		when (["", "@"]) {
			return $ccdefault;
		}
		when (["KCM", "kcm"]) {
			return "KCM:$UID";
		}
		when (m|^\d\d?$|) {
			my $i = int $_;
			if ($i > 0 && $i <= @caches) {
				return $caches[$i - 1];
			}
		}
		# ^^ and ^
		when (["^^", "^"]) {
			return "KEYRING:krb5cc";
		}
		# ^^foo
		when (m|^\^\^(.+)$|) {
			return "KEYRING:$1";
		}
		# ^foo
		when (m|^\^(.+)$|) {
			return "KEYRING:krb5cc.$1";
		}
		# +foo
		when (m|^\+$|) {
			return "DIR:$cccdir";
		}
		when (m|^\+(.*)$|) {
			return "DIR::$cccdir/$1";
		}
		# :foo/bar
		when (m|^:(.+)/$|) {
			return "DIR:$runprefix"."_$1";
		}
		when (m|^:(.+)/(.+)$|) {
			return "DIR::$runprefix"."_$1/$2";
		}
		# :foo
		when (m|^:$|) {
			return "DIR:$runprefix";
		}
		when (m|^:(.+)$|) {
			return "DIR::$runprefix/$1";
		}
		# any
		when (m|:|) {
			return $_;
		}
		when (m|/|) {
			return "FILE:$_";
		}
		default {
			return "FILE:$ccprefix$_";
		}
	}
}

sub collapse_ccname {
	my ($name) = @_;
	for ($name) {
		when ($ccdefault) {
			return "@";
		}
		when (m|^DIR::\Q$runprefix\E_(.+)/(tkt.*)$|) {
			return ":$1/$2";
		}
		when (m|^DIR::\Q$runprefix\E/(tkt.*)$|) {
			return ":$1";
		}
		when (m|^DIR::\Q$cccdir\E/(tkt.*)$|) {
			return "+$1";
		}
		when (m|^FILE:\Q$ccprefix\E(.*)$|) {
			return $1;
		}
		when (m|^FILE:(/.*)$|) {
			return $1;
		}
		#when ("API:$principal") {
		#	return "API:";
		#}
		when ("KCM:$UID") {
			return "KCM";
		}
		when ("KEYRING:krb5cc") {
			return "^";
		}
		when (m|^KEYRING:krb5cc\.(.+)$|) {
			return "^$1";
		}
		when (m|^KEYRING:(.*)$|) {
			return "^^$1";
		}
		default {
			return $_;
		}
	}
}

sub cmp_ccnames {
	my ($a, $b) = @_;
	$a = "FILE:$a" unless $a =~ /:/;
	$b = "FILE:$b" unless $b =~ /:/;
	return $a eq $b;
}

sub put_env {
	my ($key, $val) = @_;
	$ENV{$key} = $val;

	for ($ENV{SHELL}) {
		when (m{/(sh|bash|zsh)$}) {
			$val =~ s/'/'\\''/g;
			say EVAL "$key=\'$val\'; export $key;";
		}
		default {
			warn "\e[1mWarning:\e[m Unrecognized shell $ENV{SHELL}\n";
			say EVAL "$key=$val";
		}
	}
}

sub switch_ccache {
	my ($ccname) = @_;

	if (!$can_switch) {
		return 0;
	}

	for ($ccname) {
		when (m|^DIR::(.+)$|) {
			my $ccdirname = "DIR:".dirname($1);
			put_env("KRB5CCNAME", $ccdirname);
			system("kswitch", "-c", $ccname);
		}
		when (m|^KEYRING:(.*)$|) {
			my $keyname = $1;
			if (system(qq(keyctl request keyring "$keyname" > /dev/null 2>&1)) > 0) {
				# Hack around something that loses keys added to @s if it equals @us
				# TODO: deshell
				chomp(my $sdesc = qx(keyctl rdescribe \@s 2> /dev/null));
				chomp(my $udesc = qx(keyctl rdescribe \@us 2> /dev/null));
				my $keyring = ($sdesc eq $udesc) ? '@us' : '@s';
				# TODO: deshell
				system(qq(keyctl newring "$keyname" "$keyring" > /dev/null));
			}
			put_env("KRB5CCNAME", $ccname);
		}
		default {
			put_env("KRB5CCNAME", $ccname);
		}
	}

	if (system("pklist", "-q") == 0) {
		chomp(my $princ = qx(pklist -P));
		say "Switched to \e[1m$princ\e[m ($ccname)";
	} else {
		say "New ccache ($ccname)";
	}

	return 1;
}

if (!grep {-x "$_/pklist"} map {$_ || "."} split(/:/, $ENV{PATH})) {
	die "\e[1mError:\e[m Please install 'pklist' to use this tool.\n";
}

open(EVAL, ">&=", 3) or do {
	warn "\e[1mWarning:\e[m Cache switching unavailable (could not open fd#3)\n";
	$can_switch = 0;
	open(EVAL, ">/dev/null");
};

$rundir = $ENV{XDG_RUNTIME_DIR} || $ENV{XDG_CACHE_HOME} || $ENV{HOME}."/.cache";
$ccprefix = "/tmp/krb5cc_${UID}_";
$runprefix = "$rundir/krb5cc";

chomp($cccurrent = qx(pklist -N));
chomp($ccdefault = qx(unset KRB5CCNAME; pklist -N));
$ccenviron = $ENV{KRB5CCNAME} // "";

$cccdir = "";
$cccprimary = "";
if (-d $runprefix) {
	$cccdir = $runprefix;
}
if ($cccurrent =~ m|^DIR::(.+)$|) {
	$cccdir = dirname($1);
	if (-f "$cccdir/primary") {
		$cccprimary = read_file("$cccdir/primary");
	} else {
		$cccprimary = "tkt";
	}
}

@caches = enum_ccaches();

$use_color = ($ENV{TERM} && -t 1);

my $cmd = shift @ARGV;

for ($cmd) {
	when (["-h", "--help"]) {
		say for
		"Usage: kc [list]",
		"       kc <name>|\"@\" [kinit_args]",
		"       kc <number>",
		"       kc purge",
		"       kc destroy <name|number>...";
	}
	when (undef) {
		my $num = 0;

		for my $ccname (@caches) {
			my $shortname;
			my $principal;
			my $ccrealm;
			my $expiry;
			my $tgt_expiry;
			my $init_service;
			my $init_expiry;

			my $expiry_str = "";
			my $expiry_color = "";
			my $item_flag = "";
			my $flag_color = "";
			my $name_color = "";
			my $princ_color = "";

			open(my $proc, "-|", "pklist", "-c", $ccname) or die "$!";
			while (<$proc>) {
				chomp;
				my @l = split(/\t/, $_);
				for (shift @l) {
					when ("principal") {
						($principal) = @l;
						$principal =~ /.*@(.+)$/
							and $ccrealm = $1;
					}
					when ("ticket") {
						my ($t_client, $t_service, undef, $t_expiry, undef, $t_flags, undef) = @l;
						if ($t_service eq "krbtgt/$ccrealm\@$ccrealm") {
							$tgt_expiry = $t_expiry;
						}
						if ($t_flags =~ /I/) {
							$init_service = $t_service;
							$init_expiry = $t_expiry;
						}
					}
				}
			}
			close($proc);

			if (!defined $principal) {
				next;
			}

			$shortname = collapse_ccname($ccname);

			$expiry = $tgt_expiry || $init_expiry || 0;

			if ($expiry) {
				if ($expiry <= time) {
					$expiry_str = "(expired)";
					$expiry_color = "31";
					$item_flag = "×";
					$flag_color = "31";
				} else {
					$expiry_str = interval($expiry);
					$expiry_color = ($expiry > time + 1200) ? "" : "33";
				}
			}

			if ($ccname eq $cccurrent) {
				$item_flag = ($ccname eq $ccenviron) ? "»" : "*";
				$flag_color = ($expiry <= time) ? "1;31" : "1;32";
				$name_color = $flag_color;
				$princ_color = $name_color;
			} else {
				$princ_color ||= "38;5;66";
			}

			printf "\e[%sm%1s\e[m %2d ", $flag_color, $item_flag, ++$num;
			printf "\e[%sm%-15s\e[m", $name_color, $shortname;
			if (length $shortname > 15) {
				printf "\n%20s", "";
			}
			printf " \e[%sm%-40s\e[m", $princ_color, $principal;
			printf " \e[%sm%s\e[m", $expiry_color, $expiry_str;
			print "\n";
		}

		if (!$num) {
			say "No Kerberos credential caches found.";
			exit 1;
		}
	}
	when ("purge") {
		for my $ccname (@caches) {
			my $principal = read_proc("pklist", "-c", $ccname, "-P");
			say "Renewing credentials for $principal in $ccname";
			system("kinit", "-c", $ccname, "-R") == 0
				|| system("kdestroy", "-c", $ccname);
		}
	}
	when ("destroy") {
		my @destroy = grep {defined} map {expand_ccname($_)} @ARGV;
		system("kdestroy", "-c", $_) for @destroy;
	}
	when ("clean") {
		TODO;
	}
	when ("expand") {
		say expand_ccname($_) for @ARGV;
	}
	when ("list") {
		say for @caches;
	}
	when ("slist") {
		say collapse_ccname($_) for @caches;
	}
	when ("test-roundtrip") {
		for my $name (@caches) {
			my $tmp;
			say ($tmp = $name);
			say ($tmp = collapse_ccname($tmp));
			say ($tmp = expand_ccname($tmp));
			say '';
		}
	}
	when (/^=(.*)$/) {
		TODO;
	}
	when (/.+@.+/) {
		my $max_expiry = 0;
		my $max_ccname;

		for my $ccname (@caches) {
			my $principal;
			my $ccrealm;
			my $expiry;
			my $tgt_expiry;
			my $init_expiry;

			$principal = read_proc("pklist", "-P", "-c", $ccname);
			if ($principal ne $cmd) {
				next;
			}
			$principal =~ /.*@(.+)$/
				and $ccrealm = $1;

			open(my $proc, "-|", "pklist", "-c", $ccname) or die "$!";
			while (my $line = <$proc>) {
				chomp($line);
				my @l = split(/\t/, $line);
				for (shift @l) {
					when ("ticket") {
						my ($t_client, $t_service, undef, $t_expiry, undef, $t_flags) = @l;
						if ($t_service eq "krbtgt/$ccrealm\@$ccrealm") {
							$tgt_expiry = $t_expiry;
						}
						if ($t_flags =~ /I/) {
							$init_expiry = $t_expiry;
						}
					}
				}
			}
			close($proc);

			$expiry = $tgt_expiry || $init_expiry;
			if ($expiry > $max_expiry) {
				$max_expiry = $expiry;
				$max_ccname = $ccname;
			}
		}

		if ($max_expiry) {
			switch_ccache($max_ccname) || exit 1;
		} else {
			switch_ccache("new") || exit 1;
			system("kinit", $cmd, @ARGV);
		}
	}
	default {
		my $ccname = expand_ccname($cmd);
		if (defined $ccname) {
			switch_ccache($ccname) || exit 1;
			system("kinit", @ARGV) if @ARGV;
		} else {
			exit 1;
		}
	}
}
