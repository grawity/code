#!/usr/bin/env perl
use warnings;
use strict;
use Data::Dumper;
use IO::Socket;

BEGIN {
	if (eval {require Nullroute::Lib}) {
		Nullroute::Lib->import(qw(_debug _warn _err _die));
	} else {
		our ($arg0, $warnings, $errors);
		$::arg0 = (split m!/!, $0)[-1];
		$::debug = !!$ENV{DEBUG};
		sub _debug { warn "debug: @_\n" if $::debug; }
		sub _warn  { warn "warning: @_\n"; ++$::warnings; }
		sub _err   { warn "error: @_\n"; ! ++$::errors; }
		sub _die   { _err(@_); exit 1; }
	}
}

my @forwards = ();

sub usage {
	print "$_\n" for
	"Usage: notify-receive <listen> <forward>",
	"",
	"listen:",
	"    stdin",
	"    tcp!addr!port",
	"    udp!addr!port",
	"    (addr can be *)",
	"",
	"forward:",
	"    libnotify",
	"    growl!addr!port",
	"    growl!addr!port!password";
}

sub forked (&) { fork || exit shift->(); }

sub xml_escape {
	my ($str) = @_;
	$str =~ s/&/\&amp;/g;
	$str =~ s/</\&lt;/g;
	$str =~ s/>/\&gt;/g;
	$str =~ s/"/\&quot;/g;
	return $str;
}

sub handle_message {
	my ($message) = @_;
	my ($ver, $appname, $tag, $icon, $title, $text) = split(/\x01/, $message, 6);
	if ($ver != 2) {
		_warn("received invalid message '$message'");
		return;
	}
	if ($title eq "") {return;}
	if ($tag eq "") {$tag = $appname;}
	for my $fwd (@forwards) {
		&$fwd($appname, $tag, $icon, $title, $text);
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
			or _die("socket error: $!");
	} elsif ($laddr =~ /:/) {
		die "IO::Socket::INET6 required for IPv6\n";
	} else {
		$sock = IO::Socket::INET->new(%sock_args)
			or _die("socket error: $!");
	}
	return $sock;
}

sub accept_stream {
	my ($sock) = @_;

	while (my $insock = $sock->accept) {
		forked {
			chomp(my $data = <$insock>);
			close $insock;
			if ($data) { handle_message($data); }
		};
	}
}

sub accept_dgram {
	my ($sock) = @_;

	while ($sock->recv(my $data, 1024)) {
		chomp($data);
		if ($data) { handle_message($data); }
	}
}

my ($listen, $forward) = @ARGV;

# set up forwarders
if (!defined $forward) {
	usage();
	_die("missing forward address");
} elsif ($forward =~ /^libnotify$/) {
	my $dbus;
	if (eval {require Net::DBus}) {
		$dbus = Net::DBus->session;
	#} else {
	#	_die("libnotify support requires 'Net::DBus'");
	}
	
	if (defined $dbus) {
		my $libnotify = $dbus
			->get_service("org.freedesktop.Notifications")
			->get_object("/org/freedesktop/Notifications");
			
		push @forwards, sub {
			my ($appname, $tag, $icon, $title, $text) = @_;
			our %libnotify_state;
			my $state = $libnotify_state{$title} //= {};
			$text = xml_escape($text);
			# append to existing notification, if relatively new
			if (defined $state->{text} and time-$state->{sent} < 20) {
				$state->{text} .= "\n".$text;
			} else {
				$state->{text} = $text;
			}

			$state->{id} = $libnotify->Notify($appname,
							  $state->{id} // 0,
							  $icon,
							  $title,
							  $state->{text},
							  [],
							  {},
							  3_000);
			$state->{sent} = time;
		};
	} else {
		push @forwards, sub {
			my ($appname, $tag, $icon, $title, $text) = @_;
			$text = xml_escape($text);
			my @args = ("notify-send");
			push @args, "--icon=$icon" unless $icon eq "";
			# category doesn't do the same as appname, but still useful
			push @args, "--category=$appname" unless $tag eq "";
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
			my ($appname, $tag, $icon, $title, $text) = @_;
			$growl->register([
				{Name => $appname, Enabled => 'True', Sticky => 'False'},
			]);
			$growl->notify(
				Event => $appname, Title => $title, Message => $text
			);
		};
	} else {
		_die("Growl requires 'Growl::GNTP'");
	}
} else {
	_die("unsupported forward address '$forward'");
}

# set up listener
if (!defined $listen) {
	usage();
	_die("missing listen address");
} elsif ($listen =~ /^(tcp|udp)!(.+)!(.+)$/) {
	my $proto = $1;
	my $laddr = ($2 eq '*'? undef : $2);
	my $lport = $3;

	my $sock;
	if ($proto eq 'tcp') {
		$sock = socket_inet($proto, $laddr, $lport);
		$sock->listen(1);
		accept_stream($sock);
	} elsif ($proto eq 'udp') {
		$sock = socket_inet($proto, $laddr, $lport);
		accept_dgram($sock);
	}
	close $sock;
} elsif ($listen eq 'stdin') {
	while (my $data = <STDIN>) {
		chomp $data;
		if ($data) { handle_message($data); }
	}
} else {
	_die("unsupported listen address '$listen'");
}
