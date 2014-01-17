package Nullroute::Biff2;
use common::sense;
use Carp;
use Encode qw(encode);
use IO::Socket::UNIX;
use JSON;
use Socket;
use Sys::Hostname;

sub uri_encode {
	my $str = shift;
	$str =~ s/([^A-Za-z0-9.!~*'()-])/sprintf("%%%02X", ord($1))/seg;
	return $str;
}

sub xdg_runtime_dir {
	$ENV{XDG_RUNTIME_DIR} // $ENV{XDG_CACHE_HOME} // "$ENV{HOME}/.cache";
}

sub joinline {
	join(" ", map {uri_encode $_} @_);
}

sub findsocket {
	my $dir = xdg_runtime_dir;
	"$dir/mq.socket";
}

sub notify {
	my ($class, $tag, $data) = @_;

	my $buf = ref $data ? JSON->new->utf8->encode($data) : encode("UTF-8", $data);

	my $name = sprintf('%s!%s!biff2', hostname, $<);
	my $sock = IO::Socket::UNIX->new(
				Type => SOCK_STREAM,
				Peer => findsocket(),);

	if ($sock) {
		my $line = $sock->getline;
		unless ($line eq ". nmq-1.0\n") {
			croak "Protocol mismatch: $line";
		}

		$sock->autoflush(0);
		say $sock joinline("name", $name);
		say $sock joinline("send", $tag // "sys", $buf);
		say $sock joinline("quit");
		$sock->flush;
		1 while $sock->getline;
		close $sock;
	} else {
		$ENV{DEBUG} && warn "Connection failed: $!\n";
	}
}

1;
