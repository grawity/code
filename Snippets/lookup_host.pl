# Resolving addresses via getaddrinfo, unpacking sockaddr structures
# Status: working, code snippets only
use strict;
use Socket;
use Socket6;

sub uniq {
	my %seen;
	grep {!$seen{$_}++} @_;
}

sub lookup_host {
	my ($host, $service) = @_;
	my (@addresses, %hint);

	%hint = (socktype => SOCK_RAW);
	my ($err, @ai) = getaddrinfo($host, $service // "", \%hint);
	if ($err) {
		die $err;
	}
	for my $entry (@ai) {
		my @sa = unpack_sockaddr($entry->{family}, $entry->{addr});
		push @addresses, inet_ntop($entry->{family}, $sa[1]);
	}
	return uniq @addresses;
}

sub unpack_sockaddr {
	my ($family, $sa) = @_;
	my %unpack = (
		AF_INET,	\&Socket::unpack_sockaddr_in,
		AF_INET6,	\&Socket6::unpack_sockaddr_in6,
		AF_UNIX,	\&Socket::unpack_sockaddr_un,
	);
	if (exists $unpack{$family}) {
		return $unpack{$family}->($sa);
	} else {
		warn "Unknown address family $family";
	}
}

print "$_\n" for lookup_host(@ARGV);
