#!perl
package Nullroute::Rpc::Client;
use common::sense;
use Nullroute::Rpc::Peer;
use Nullroute::Rpc::ProxyClass;

# mid-level "client" class for connecting a ::Peer and calling methods

sub new {
	my ($class, %args) = @_;
	my $self = {
		peer => undef,
	};

	bless $self, $class;
}

sub connect_stdio {
	my ($self) = @_;
	$self->connect_fd(\*STDIN, \*STDOUT);
}

sub connect_fd {
	my ($self, $rfd, $wfd) = @_;
	$self->{peer} = Nullroute::Rpc::Peer->new($rfd, $wfd // $rfd);
}

sub call {
	my ($self, $req) = @_;
	$self->{peer}->rpc_send_obj($req);
	$self->{peer}->rpc_recv_obj();
}

sub call_method {
	my ($self, $class, $method, $args) = @_;
	my $req = [$class, $method, $args];
	$self->{peer}->rpc_send_obj($req);
	$self->{peer}->rpc_recv_obj();
}

sub get_class {
	my ($self, $class) = @_;
	return Nullroute::Rpc::ProxyClass->new($self, $class);
}

1;
