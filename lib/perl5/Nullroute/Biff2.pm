#!perl
package Nullroute::Biff2;
use common::sense;
use Carp;
use Data::Dumper;
use IO::Socket::UNIX;
use JSON;
use Socket;
use Sys::Hostname;

sub findsocket {
	$ENV{BIFF2_SERVER} // "$ENV{HOME}/.cache/S.biff2";
}

sub notify {
	my ($class, $path, $data) = @_;

	my $buf = JSON->new->utf8->encode($data);

	my $sock = IO::Socket::UNIX->new(
				Type => SOCK_DGRAM,
				Peer => findsocket(),
			);

	if ($sock) {
		# TODO TODO TODO: Just find a Perl/Python HTTP
		# server library. Or heroku the fucker.
		# 
		# Clients send JSON using HTTP POST
		# Subscribers: long-lived polls? tcp? etc.
		#
		$sock->autoflush(0);
		say $sock "POST $path STFU/1.0";
		say $sock "Origin-Host: ".hostname();
		say $sock "Content-Length: ".length($buf);
		say $sock "";
		say $sock $buf;
		$sock->flush;
		close $sock;
	} else {
		$ENV{DEBUG} && warn "Connection failed: $!\n";
	}
}

1;
