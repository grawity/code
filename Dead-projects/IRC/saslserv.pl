#!/usr/bin/env perl
use warnings;
use strict;
use Authen::SASL;
use MIME::Base64;

sub sasl_start {
	my ($state, $mech, %callback) = @_;

	$state->{sasl} = Authen::SASL->new(
				mechanism => $mech,
				callback => {});

	$state->{conn} = $state->{sasl}->server_new("host", "rain.nullroute.eu.org");

	$state->{step} = 0;
}

sub sasl_step {
	my ($state, $indata) = @_;

	if ($state->{conn}->need_step) {
		my $outdata;
		if ($state->{step} == 0) {
			$outdata = $state->{conn}->server_start($indata);
		} else {
			$outdata = $state->{conn}->server_step($indata);
		}
		$state->{step}++;

		return more => $outdata;
	} else {
		return done => 1//$state->{conn}->is_success;
	}
}

my $c = {};
sasl_start($c, "GSSAPI");
while (1) {
	my $indata = decode_base64(<STDIN>);
	my @out = sasl_step($c, $indata);
	print $out[0], " - ", encode_base64($out[1]), "\n";
}
