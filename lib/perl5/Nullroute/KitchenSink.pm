package Nullroute::KitchenSink;
use base "Exporter";
use strict;
use utf8;
use warnings;
use IO::Socket::UNIX;
use Math::Trig;

our @EXPORT = qw(
	coord_distance
	shannon_entropy
);

### math

sub coord_distance {
	my ($lon1, $lat1, $lon2, $lat2) = @_;

	# "haversine" formula based on code from:
	# http://www.movable-type.co.uk/scripts/latlong.html

	my $R = 6_371_000;
	my $φ1 = deg2rad($lat1);
	my $φ2 = deg2rad($lat2);
	my $Δφ = deg2rad($lat2 - $lat1);
	my $Δλ = deg2rad($lon2 - $lon1);

	my $a = sin($Δφ/2)**2 + cos($φ1) * cos($φ2) * sin($Δλ/2)**2;
	my $c = 2 * atan2(sqrt($a), sqrt(1-$a));
	return $R * $c;
}

sub shannon_entropy {
	my ($str) = @_;
	my $length = length($str);
	my @histogram;
	my $entropy;

	# algorithm used by strongSwan to check PSK quality

	$histogram[ord $_]++ for split(//, $str);

	$entropy -= $_ for
			map {$_ * log($_) / log(2)}
			map {$_ / $length}
			grep {$_} @histogram;

	return $entropy;
}

1;
