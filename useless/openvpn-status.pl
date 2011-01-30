#!/usr/bin/env perl
# Parses the OpenVPN "status" files, versions 1 and 3

use strict;
use Data::Dumper;

sub parse_v1 {
	my ($file) = @_;
	my $state = "start";
	my $skip = 0;
	my @clients = ();
	my @routes = ();

	open my $fh, "<", $file or die $!;
	while (<$fh>) {
		if ($state eq "start") {
			if (/^OpenVPN CLIENT LIST/) {
				$state = "clients";
				$skip = 2;
			}
		}
		elsif ($state eq "clients" and --$skip < 0) {
			if (/^ROUTING TABLE$/) {
				$state = "routes";
				$skip = 1;
			}
			elsif (/^(.+?),(.+?),(\d+?),(\d+?),(.+)$/) {
				push @clients, {user => $1, addr => $2,
					sent => int $3, rcvd => int $4};
			}
		}
		elsif ($state eq "routes" and --$skip < 0) {
			if (/^GLOBAL STATS$/) {
				$state = "stats";
			}
			elsif (/^(.+?),(.+?),(.+?),(.+)$/) {
				push @routes, {
					addr => $1,
					user => $2,
					nexthop => $3,
				};
			}
		}
		# elsif ($state eq "stats") {
	}
	return (clients => \@clients, routes => \@routes);
}

sub parse_v3 {
	my ($file) = @_;
	my @clients = ();
	my @routes = ();
	open my $fh, "<", $file or die $!;
	while (<$fh>) {
		my @line = split(/\t/, $_);
		if ($line[0] eq "CLIENT_LIST") {
			push @clients, {
				user => ($line[1] eq "UNDEF" ? undef : $line[1]),
				addr => $line[2],
				vaddr => $line[3],
				sent => int $line[4],
				rcvd => int $line[5],
			};
		}
		elsif ($line[0] eq "ROUTING_TABLE") {
			push @routes, {
				addr => $line[1],
				user => $line[2],
				nexthop => $line[3],
			};
		}
	}
	return (clients => \@clients, routes => \@routes);
}

my $log = "/etc/openvpn/210-openvpn-status.log";

my %status = parse_v3($log);
print Dumper(\%status);

=off
my @clients = @{$status{clients}};
my @routes = @{$status{routes}};

print "# Clients\n";
my $fmt = "%-12s %-24s %8s %8s\n";
printf $fmt, "USER", "REMOTE", "SENT", "RCVD";
printf $fmt, $_->{user}, $_->{addr}, $_->{sent}, $_->{rcvd} for @clients;

print "\n# Routes\n";
my $fmt = "%-18s %-22s %-12s\n";
printf $fmt, "DESTINATION", "NEXT HOP", "USER";
printf $fmt, $_->{addr}, $_->{nexthop}, $_->{user} for @routes;
=cut
