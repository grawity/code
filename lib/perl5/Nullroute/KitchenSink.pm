package Nullroute::KitchenSink;
use warnings;
use strict;
use base "Exporter";
use IO::Socket::UNIX;

use constant {
	DATE_FMT_MBOX	=> '%a %b %_d %H:%M:%S %Y',
	DATE_FMT_MIME	=> '%a, %d %b %Y %H:%M:%S %z',
	DATE_FMT_ISO	=> '%Y-%m-%dT%H:%M:%S%z',
};

our @EXPORT = qw(
	DATE_FMT_MBOX
	DATE_FMT_MIME
	sd_notify
);

sub sd_notify {
	if (my $path = $ENV{NOTIFY_SOCKET}) {
		$path =~ s/^@/\0/;
		my $data = join("\n", @_);
		my $sock = IO::Socket::UNIX->new(Peer => $path,
		                                 Type => SOCK_DGRAM);
		if ($sock) {
			$sock->send($data);
			$sock->close;
		}
	}
}

1;
