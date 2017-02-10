#!/usr/bin/env perl
use IO::Socket::UNIX;

sub notify {
	my @args = @_;

	my $path = $ENV{NOTIFY_SOCKET} // return;
	$path =~ s/^@/\0/;

	my $sock = IO::Socket::UNIX->new(Type => SOCK_DGRAM,
					Peer => $path);

	$sock->print(join("\n", @args));
}
