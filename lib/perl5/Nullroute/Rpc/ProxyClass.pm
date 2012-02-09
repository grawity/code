#!perl
package Nullroute::Rpc::ProxyClass;
use common::sense;
use Carp;

# high-level "proxy class" class for calling methods more-or-less seamlessly

sub new {
	my ($class, $client, $rclass) = @_;
	my $self = {
		client	=> $client,
		rclass	=> $rclass,
	};
	bless $self, $class;
}

sub DESTROY {}

sub AUTOLOAD {
	my ($self, @args) = @_;
	my ($name) = (our $AUTOLOAD =~ /.+::(.+?)$/);
	if ($name =~ /^_/) {
		croak "Attempted to autoload a private method $self->{class}::$name";
	}
	$self->_call($name, @args);
}

sub _call {
	my ($self, $method, @args) = @_;
	$self->{client}->call_method($self->{rclass}, $method, \@args);
}

1;
