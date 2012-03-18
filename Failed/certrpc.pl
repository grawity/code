#!/usr/bin/env perl
package Nullroute::Cert::Authority;
use common::sense;

sub new {
	bless {}, shift;
}

sub init_serial {
	my ($self) = @_;
	if (open(my $fh, "<", $self->{path}."/db/serial")) {
		chomp(my $serial = <$fh>);
		close $fh;
		$self->{serial} = 
	}
}

sub next_serial {
	my ($self) = @_;
	my $next = 

sub ca_create_request {
	my ($subj) = @_;
	my $serial = ca_next_serial();

	my $req_path = "$datadir/req/$serial";
	my $key_path = "$datadir/key/$serial";

	my @args = ("req",
			"-utf8",
			"-new",
			"-subj" => $subject,
			"-out" => $req_path,
			"-keyout" => $key_path,
			"-nodes",
			);

	if (openssl(@args)) {
		return $serial;
	} else {
		unlink $req_path;
		unlink $key_path;
		return undef;
	}
}

say ca_create_request;
