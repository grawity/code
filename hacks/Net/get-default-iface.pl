#!/usr/bin/env perl

my $best_dev = undef;
my $best_metric = 0;

open(my $fh, "-|", "ip", "-4", "route") or die "$!";
while (<$fh>) {
	chomp;
	my ($target, %route) = split;
	if ($target eq "default") {
		if (!defined $best_dev || $route{metric} < $best_metric) {
			$best_dev = $route{dev};
			$best_metric = $route{metric};
		}
	}
}
close($fh);

print "$best_dev $best_metric\n";
