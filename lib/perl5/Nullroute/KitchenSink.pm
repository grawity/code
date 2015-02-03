package Nullroute::KitchenSink;
use warnings;
use strict;
use base "Exporter";
use IO::Socket::UNIX;

use constant {
	DATE_FMT_MBOX	=> '%a %b %_d %H:%M:%S %Y',
	DATE_FMT_MIME	=> '%a, %d %b %Y %H:%M:%S %z',
	DATE_FMT_ISO	=> '%Y-%m-%dT%H:%M:%S%z',

	NIN_GENDER_FEMALE	=> 0,
	NIN_GENDER_MALE		=> 1,
};

our @EXPORT = qw(
	DATE_FMT_MBOX
	DATE_FMT_MIME

	lt_nin_checksum
	lt_nin_parse
	lt_nin_random
	lt_nin_valid

	sd_notify
);

### National identification numbers

sub lt_nin_checksum {
	my ($nin) = @_;

	my @digits;

	if ($nin =~ /^([0-9]{10})[0-9]?$/) {
		@digits = map {int} split(//, $1);
	} else {
		return undef;
	}

	my ($b, $c, $d, $e) = (1, 3, 0, 0);

	for my $i (0..9) {
		$d += $digits[$i] * $b;
		$e += $digits[$i] * $c;
		$b = ($b < 9) ? $b + 1 : 1;
		$c = ($c < 9) ? $c + 1 : 1;
	}

	$d %= 11;
	$e %= 11;

	my $k = ($d < 10) ? $d :
	        ($e < 10) ? $e : 0;

	return join("", @digits, $k);
}

sub lt_nin_valid {
	my ($nin) = @_;

	return $nin eq (lt_nin_checksum($nin) // "");
}

sub lt_nin_parse {
	my ($nin) = @_;

	my @digits = map {int} split(//, $nin);
	my ($csum, $gender, $year, $month, $day);

	$gender = $digits[0] % 2;

	$digits[0] += $gender;

	$year  = 1700 + $digits[0] * 50
	       + $digits[1] * 10 + $digits[2];
	$month = $digits[3] * 10 + $digits[4];
	$day   = $digits[5] * 10 + $digits[6];

	#_debug("parsed [$nin] to <$year, $month, $day>");

	return ($gender, $year, $month, $day);
}

sub lt_nin_random {
	my $nin;
	$nin = sprintf("%011d", (1_00_20_00_0000 + int rand 69_99_9999));
	$nin = lt_nin_checksum($nin);
	return $nin;
}

### systemd

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
