#!/usr/bin/env perl
use warnings;
use strict;
use Data::Dumper;
use Socket qw(:addrinfo);

sub do_resolve {
	my ($host) = @_;

	my $hints = {flags => AI_CANONNAME};

	my ($err, @res) = getaddrinfo($host, undef, $hints);

	warn "fqdn: could not resolve '$host': $err\n" if $err;

	for my $res (@res) {
		my ($family_str, $addr_str);

		if ($res->{family} == Socket::AF_INET) {
			$family_str = "AF_INET";
			my ($port, $addr) = Socket::unpack_sockaddr_in($res->{addr});
			$addr_str = Socket::inet_ntop($res->{family}, $addr);
		}
		elsif ($res->{family} == Socket::AF_INET6) {
			$family_str = "AF_INET6";
			my ($port, $addr, $scope, $flow) = Socket::unpack_sockaddr_in6($res->{addr});
			$addr_str = Socket::inet_ntop($res->{family}, $addr);
			if ($scope) { $addr_str .= " % " . $scope; }
		}
		else {
			$family_str = "??";
		}
		print "$family_str { $addr_str }\n";
	}
}

do_resolve($_) for @ARGV;
