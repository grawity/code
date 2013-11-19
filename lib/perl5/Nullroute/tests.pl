#!/usr/bin/env perl
use warnings;
use strict;
use JSON;

use Data::Dumper;
use Nullroute::IRC;

my $json = JSON->new->utf8->allow_nonref;

sub parse_test {
	my ($file) = @_;
	my @tests;
	if (open(my $fh, "<", $file)) {
		while (my $line = <$fh>) {
			chomp($line);
			next if !length $line;
			next if $line =~ m!^//!;
			push @tests, $json->decode("[$line]");
		}
		close($fh);
	} else {
		die "$@";
	}
	return @tests;
}

sub vcmp {
	my ($a, $b) = @_;
	if (defined($a) && defined($b)) {
		my $sa = $json->encode($a);
		my $sb = $json->encode($b);
		return $sa eq $sb;
	} elsif (defined($a) || defined($b)) {
		return 0;
	} else {
		return 1;
	}
}

sub run_test {
	my ($file, $func) = @_;
	my ($passed, $failed) = (0, 0);
	my @t = parse_test($file);
	for my $test (@t) {
		my $msg;
		my ($input, $wanted_output) = @$test;
		my $actual_output = $func->($input);
		if (vcmp($wanted_output, $actual_output)) {
			$msg = " OK ";
			$passed += 1;
		} else {
			$msg = "FAIL";
			$failed += 1;
		}
		printf "%s: %s -> %s\n", $msg,
			$json->encode($input),
			$json->encode($actual_output);
		if ($msg eq "FAIL") {
			printf "\e[33m%s: %s -> %s\e[m\n", "WANT",
				$json->encode($input),
				$json->encode($wanted_output);
		}
	}
	print "Tests: $passed passed, $failed failed\n";
	return $failed;
}

sub test_split {
	my $input = shift;
	my @output = Nullroute::IRC::split_line($input);
	return \@output;
}

sub test_join {
	my $input = shift;
	return "nil";
}

my $dir = "../../tests";

my $f = 0;
$f += run_test("$dir/irc-split.txt", \&test_split);
#$f += run_test("$dir/irc-join.txt", \&test_join);

print "Total: $f failed\n";

exit($f > 0);
