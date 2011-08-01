#!/usr/bin/env perl
use warnings;
use strict;
use IO::Socket;
use Data::Dumper;

my $listen = shift @ARGV;
my $forward = shift @ARGV;
my @forwards = ();

my ($dbus, $libnotify);

sub usage {
	print STDERR <<EOF;
Usage: notify-receive <listen> <forward>

listen:
	stdin
	tcp!addr!port
	udp!addr!port
	(addr can be *)
forward:
	libnotify
	growl!addr!port
	growl!addr!port!password
EOF
	exit 2;
}

### Helpers

# perlcritic can DIAF.
sub forked(&) {
	my $code = shift;
	my $pid = fork();
	if ($pid == 0) {exit &$code;}
	else {return $pid;}
}

sub xml_escape {
	($_) = @_; s/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; return $_;
}

sub handle_message {
	my ($message) = @_;
	my ($appname, $icon, $title, $text) = split / \| /, $message;
	if ($title eq "") {return;}
	for my $fwd (@forwards) {
		&$fwd($appname, $icon, $title, $text);
	}
}

sub socket_inet {
	my ($proto, $laddr, $lport) = @_;

	my $sock;
	my %sock_args = (
		Proto => $proto,
		LocalAddr => $laddr,
		LocalPort => $lport,
		ReuseAddr => 1,
	);
	if (eval {require IO::Socket::INET6}) {
		$sock = IO::Socket::INET6->new(%sock_args)
			or die "socket: $!";
	} elsif ($laddr =~ /:/) {
		die "IO::Socket::INET6 required for IPv6\n";
	} else {
		$sock = IO::Socket::INET->new(%sock_args)
			or die "socket: $!";
	}
	return $sock;
}

sub accept_stream {
	my $sock = shift;
	while (my $insock = $sock->accept) {
		forked {
			chomp(my $data = <$insock>);
			close $insock;
			$data and handle_message($data);
		};
	}
}

sub accept_dgram {
	my $sock = shift;
	while ($sock->recv(my $data, 1024)) {
		chomp $data;
		$data and handle_message($data);
	}
}

# set up forwarders
if (!defined $forward) {
	usage;
} elsif ($forward =~ /^libnotify$/) {
	my $dbus;
	if (eval {require Net::DBus}) {
		$dbus = Net::DBus->session;
	#} else {
	#	print STDERR "error: DBus requires Net::DBus\n";
	#	exit 2;
	}
	
	if (defined $dbus) {
		my $libnotify = $dbus->get_service("org.freedesktop.Notifications")
			->get_object("/org/freedesktop/Notifications");
			
		push @forwards, sub {
			my ($appname, $icon, $title, $text) = @_;
			our %libnotify_state;
			my $state = $libnotify_state{$title} //= {};

			$text = xml_escape($text);
			# append to existing notification, if relatively new
			if (defined $state->{text} and time-$state->{sent} < 20) {
				$state->{text} .= "\n".$text;
			} else {
				$state->{text} = $text;
			}

			$state->{id} = $libnotify->Notify($appname, $state->{id} // 0,
				$icon, $title, $state->{text}, [], {}, 3000);
			$state->{sent} = time;
		};
	} else {
		push @forwards, sub {
			my ($appname, $icon, $title, $text) = @_;
			$text = xml_escape($text);
			my @args = ("notify-send");
			push @args, "--icon=$icon" unless $icon eq "";
			# category doesn't do the same as appname, but still useful
			push @args, "--category=$appname" unless $appname eq "";
			push @args, $title;
			push @args, $text unless $text eq "";
			system @args;
		};
	}
} elsif ($forward =~ /^growl!(.+?)!(.+?)(?:!(.+?))?$/) {
	if (eval {require Growl::GNTP}) {
		my $growl = Growl::GNTP->new(
			PeerHost => $1,
			PeerPort => $2,
			Password => $3,
			AppName => "notify_receive",
		);
		push @forwards, sub {
			my ($appname, $icon, $title, $text) = @_;
			$growl->register([
				{Name => $appname, Enabled => 'True', Sticky => 'False'},
			]);
			$growl->notify(
				Event => $appname, Title => $title, Message => $text
			);
		};
	} else {
		print STDERR "error: Growl requires Growl::GNTP\n";
		exit 2;
	}
} else {
	print STDERR "error: unsupported forward address: $forward\n";
	usage;
}

# set up listener
if (!defined $listen) {
	usage;
} elsif ($listen =~ /^(tcp|udp)!(.+)!(.+)$/) {
	my $proto = $1;
	my $laddr = ($2 eq '*'? undef : $2);
	my $lport = $3;

	my $sock;

	if ($proto eq 'tcp') {
		$sock = socket_inet($proto, $laddr, $lport);
		$sock->listen(1);
		accept_stream $sock;
	} elsif ($proto eq 'udp') {
		$sock = socket_inet($proto, $laddr, $lport);
		accept_dgram $sock;
	}

	close $sock;
} elsif ($listen eq 'stdin') {
	while (my $data = <STDIN>) {
		chomp $data;
		$data and handle_message($data);
	}
} else {
	print STDERR "error: unsupported listen address: $listen\n";
	usage;
}
