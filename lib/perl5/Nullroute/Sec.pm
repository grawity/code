package Nullroute::Sec;
use parent "Exporter";
use strict;
use Net::Netrc;
use Nullroute::Lib qw(_debug);

our @EXPORT = qw(get_netrc);

sub _str {
	my ($str) = @_;
	defined($str) ? "'$str'" : "(nil)";
}

sub _lookup_netrc {
	my ($machines, %opt) = @_;
	my $login = $opt{login};
	my $no_default = 1;
	my $fallback;
	for my $machine (@$machines) {
		_debug("searching for "._str($machine).", login="._str($login));
		my $en = Net::Netrc->lookup($machine, $login);
		if (defined $en) {
			_debug("- found entry for machine "._str($en->{machine}));
			if (defined $en->{machine}) {
				_debug("- returning entry");
				return $en;
			} elsif (!$no_default) {
				_debug("- storing as fallback");
				$fallback //= $en;
			}
		}
	}
	_debug("- returning fallback");
	return $fallback;
}

sub get_netrc {
	my ($machine, $login) = @_;

	my $service;
	my @machines;
	my $service_required = 0;

	if ($machine =~ m{^([^/]+)[@/](.+)$}) {
		$service = $1;
		$machine = $2;
	}
	if ($service) {
		push @machines, $service.'/'.$machine;
		push @machines, $service.'@'.$machine;
	}
	if (!$service || !$service_required) {
		push @machines, $machine;
	}

	my $entry = _lookup_netrc(\@machines, $login);
	return $entry;
}
