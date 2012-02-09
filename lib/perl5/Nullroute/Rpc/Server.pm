#!perl
package Nullroute::Rpc::Server;
use common::sense;
use Carp;
use Nullroute::Rpc::Peer;

sub new {
	my ($class) = @_;
	my $self = {
		peer	=> undef,
		handler	=> undef,
	};
	bless $self, $class;
}

sub connect_fd {
	my ($self, $rfd, $wfd) = @_;
	$self->{peer} = Nullroute::Rpc::Peer->new($rfd, $wfd // $rfd);
}

sub set_handler {
	my ($self, $sub) = @_;
	$self->{handler} = $sub;
}

sub loop {
	my ($self) = @_;

	if (!$self->{peer}) {
		croak "Starting main loop without a connection";
	}
	if (!$self->{handler}) {
		croak "Starting main loop without a request handler";
	}

	while (my $in = $self->{peer}->rpc_recv_obj) {
		my $out = $self->{handler}->($self, $in);
		$self->{peer}->rpc_send_obj($out);
	}
}

1;
