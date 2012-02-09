#!perl
package Nullroute::Rpc::Peer;
use common::sense;
use Carp;
use IO::Handle;
use JSON;

use constant {
	HDR_MAGIC	=> "NullRPC:",
	HDR_MAGIC_LEN	=> 8,
	HDR_LENGTH_LEN	=> 8,
	HDR_LEN		=> 16,
};

# low-level "peer" class for exchanging data over a pair of FDs

sub new {
	my ($class, $rfd, $wfd) = @_;
	my $self = {
		rfd	=> $rfd // \*STDIN,
		wfd	=> $wfd // $rfd // \*STDOUT,
		encoder	=> undef,
		decoder	=> undef,
	};
	binmode $self->{rfd}, ":raw";
	binmode $self->{wfd}, ":raw";
	bless $self, $class;
}

sub close {
	my ($self) = @_;
	$self->{rfd}->close;
	$self->{wfd}->close;
}

# send/receive packets of length + binary data

sub rpc_send_packed {
	my ($self, $buf) = @_;
	$self->{wfd}->printf('NullRPC:%08x', length($buf));
	$self->{wfd}->print($buf);
	$self->{wfd}->flush;
}

sub rpc_recv_packed {
	my ($self) = @_;
	my ($len, $buf);
	unless ($self->{rfd}->read($buf, 16) == 16) {
		return undef;
	}
	unless ($buf =~ /^NullRPC:[0-9a-f]{8}$/) {
		chomp($buf .= $self->{rfd}->getline);
		$self->{wfd}->print("Protocol mismatch.\n");
		$self->close;
		croak "RPC: protocol mismatch, received '$buf'";
		return undef;
	}
	$len = hex(substr($buf, 8));
	unless ($self->{rfd}->read($buf, $len) == $len) {
		return undef;
	}
	return $buf;
}

# send/receive Perl/JSON objects

sub rpc_serialize {
	return encode_json(shift // {});
}

sub rpc_unserialize {
	return decode_json(shift || '{}');
}

sub rpc_send_obj {
	my ($self, $obj) = @_;
	my $buf = rpc_serialize($obj);
	$Nullroute::Rpc::DEBUG and warn "RPC: --> $buf\n";
	if ($self->{decoder}) {
		$buf = $self->{decoder}->($self, $buf);
	}
	$self->rpc_send_packed($buf);
}

sub rpc_recv_obj {
	my ($self) = @_;
	my $buf = $self->rpc_recv_packed;
	if (!defined $buf) {
		return undef;
	}
	if ($self->{encoder}) {
		$buf = $self->{encoder}->($self, $buf);
	}
	$Nullroute::Rpc::DEBUG and warn "RPC: <-- $buf\n";
	return rpc_unserialize($buf);
}

1;
