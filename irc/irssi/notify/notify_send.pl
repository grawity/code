use warnings;
use strict;
use utf8;

use feature qw(state switch);
use Irssi;
use Socket;
use IO::Socket::INET;
use IO::Socket::UNIX;

our $VERSION = "0.8";
our %IRSSI = (
	name        => 'notify-send',
	description => 'Sends hilight messages over DBus, TCP or UDP',
	authors     => 'Mantas Mikulėnas',
	contact     => 'grawity@gmail.com',
	license     => 'MIT (Expat) <https://spdx.org/licenses/MIT>',
);

my $appname = "irssi";

my @hilights = (
	# Put regexps below, as per the example, just without the "#"

	# qr/whatever/i,
);

sub any (&@) { my $f = shift; for (@_) { return 1 if $f->(); } return 0; }

sub do_hilight {
	my ($server, $msg, $nick, $userhost, $target, $type) = @_;

	# Unfortunately, irssi only checks hilights at time of printing the
	# message, when such information as "nick" and "message" is effectively
	# lost in formatting. Even if we tried to regexp the sender's nick out
	# of the message, it would break with 60% of the themes out there.
	#
	# Besides, most people are fine with being notified when someone says
	# their name. The rest are welcome to modify the rules below.

	my $mynick = $server->{nick};
	my $ischannel = $server->ischannel($target);

	# Ignore server messages and notices
	return 0 unless defined $userhost;

	# Public messages:
	#  + accept if contains our nick
	#  + accept if matches a regex in @hilights
	return 1 if $ischannel and (
		$msg =~ /\b\Q$mynick\E\b/i
		or any {$msg =~ $_} @hilights
	);

	# Ignore private notices from *!*@services.*
	return 0 if !$ischannel and $type eq "notice" and $userhost =~ /\@services\./;
}

sub xml_escape {
	for (shift) {
		s/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; return $_;
	}
}

sub getservice {
	my ($name, $proto) = @_;

	if ($name =~ /^[0-9]+$/) {
		return int $name;
	} elsif (my ($rname, $aliases, $port, $rproto) = getservbyname($name, $proto)) {
		return $port;
	}
}

sub send_file {
	my ($data, $path) = @_;

	if (open my $fh, ">>", $path) {
		print $fh $data;
		close $fh;
		return 1;
	} else {
		return 0, $!;
	}
}

sub send_dbus {
	my ($tag, $title, $text) = @_;

	state $dbuserror = 0;
	state $libnotify = undef;
	state %history = ();

	if (!defined $libnotify) {
		if (!defined $ENV{DISPLAY} and !defined $ENV{DBUS_SESSION_BUS_ADDRESS}) {
			use Data::Dumper;
			return $dbuserror++, "DBus session bus not available";
		}

		if (eval {require Net::DBus}) {
			my $bus = Net::DBus->session;
			my $svc = $bus->get_service("org.freedesktop.Notifications");
			my $obj = $svc->get_object("/org/freedesktop/Notifications");
			$libnotify = $obj;
		}
		else {
			return 0, "libnotify support requires Net::DBus";
		}
	}

	my $icon = Irssi::settings_get_str("notification_icon");
	my $actions = [];
	my $hints = {};
	my $timeout = 3000;

	my $state = $history{$title} //= {};

	$text = xml_escape($text);

	if (defined $state->{text} and (time - $state->{sent}) < 20) {
		$state->{text} .= "\n".$text;
	} else {
		$state->{text} = $text;
	}

	$state->{sent} = time;
	$state->{id} = $libnotify->Notify($appname, $state->{id} // 0, $icon,
				$title, $state->{text}, $actions, $hints, $timeout);
	return 1;
}

sub send_growl {
	my ($title, $text) = @_;

	state $growl = 0;

	# To do: Mac::Growl vs Growl::GNTP?
	if (eval {require Mac::Growl}) {
		if (!$growl) {
			my @default = qw(Hilight);
			my @all = @default;
			Mac::Growl->RegisterNotification($appname, \@all, \@default);
			$growl = 1;
		}
		Mac::Growl->PostNotification($appname, "Hilight", $title, $text);
	} else {
		#return 0, "Growl support requires Mac::Growl";
		my @args = ("growlnotify");
		push @args, ("-n", $appname) if $appname;
		push @args, ("-m", $text) if $text;
		push @args, $title;
		return system(@args) == 0;
	}
}	

sub send_inet {
	my ($data, $proto, $host, $service) = @_;

	my $port = getservice($service, $proto)
		or return 0, "Unknown service '$service/$proto'";

	my %sock_args = (
		PeerAddr => $host,
		PeerPort => $port,
		Proto => $proto,
		Blocking => 0,
	);

	my $sock;

	if (eval {require IO::Socket::INET6}) {
		$sock = IO::Socket::INET6->new(%sock_args);
	} elsif ($host =~ /:/) {
		return 0, "IPv6 support requires IO::Socket::INET6";
	} else {
		$sock = IO::Socket::INET->new(%sock_args);
	}

	if (defined $sock) {
		print $sock $data;
		$sock->close();
		return 1;
	} else {
		return 0, $!;
	}
}

sub send_inet_ssl {
	my ($data, $host, $service) = @_;

	my $port = getservice($service, "tcp")
		or return 0, "Unknown service '$service/tcp'";

	my %sock_args = (
		PeerAddr => $host,
		PeerPort => $port,
		Proto => "tcp",
		Blocking => 0,
		SSL_version => "TLSv1",
		SSL_ca_path => "/etc/ssl/certs",
	);

	my $sock;

	if (eval {require IO::Socket::SSL}) {
		$sock = IO::Socket::SSL->new(%sock_args)
			or return 0, $!;
	} else {
		return 0, "SSL support requires IO::Socket::SSL";
	}

	print $sock $data;
	$sock->close;
	return 1;
}

sub send_unix {
	my ($data, $type, $address) = @_;

	my $sock = IO::Socket::UNIX->new(
			Type => ($type eq 'stream'? SOCK_STREAM : SOCK_DGRAM),
			Peer => $address) or return 0, $!;

	print $sock $data;
	$sock->close;
	return 1;
}

sub notify {
	my ($dest, $tag, $title, $text) = @_;

	my $icon = Irssi::settings_get_str("notification_icon");

	my $rawmsg = join("\x01", 2, $appname, $tag, $icon, $title, $text)."\n";

	for ($dest) {
		when (/^(libnotify|dbus)$/) {
			send_dbus($tag, $title, $text);
		}
		when (/^file!(.+)$/) {
			send_file($rawmsg, $1);
		}
		when (/^growl$/) {
			send_growl($title, $text);
		}
		when (/^ssl!(.+?)!(.+?)$/) {
			send_inet_ssl($rawmsg, $1, $2);
		}
		when (/^(tcp|udp)!(.+?)!(.+?)$/) {
			send_inet($rawmsg, $1, $2, $3);
		}
		when (/^unix!(stream|dgram)!(.+)$/) {
			send_unix($rawmsg, $1, $2);
		}
		when (/^unix!(.+)$/) {
			send_unix($rawmsg, "stream", $1);
		}
		default {
			$dest =~ /^([^!]+)/;
			0, "Unsupported address type '$1'";
		}
	}
}

sub on_message {
	my ($server, $msg, $nick, $userhost, $target, $type) = @_;

	# remove mIRC colors
	$msg =~ s/\x03[0-9]{1,2}(,[0-9]{1,2})?//g;
	# remove all other control characters
	$msg =~ s/[\x01-\x08\x0A-\x1F]//g;

	return unless do_hilight(@_);

	my ($tag, $title);
	if ($server->ischannel($target)) {
		$tag = $target;
		$title = "$nick on $target";
	} else {
		$tag = $nick;
		$title = $nick;
	}

	my $dests = Irssi::settings_get_str("notify_targets");
	for my $dest (split / /, $dests) {
		my @ret = notify($dest, $tag, $title, $msg);
		$ret[0] or Irssi::print("Could not notify $dest: $ret[1]");
	}
}

Irssi::settings_add_str("libnotify", "notify_targets", "libnotify");
Irssi::settings_add_str("libnotify", "notification_icon", "avatar-default");

Irssi::signal_add("message public", sub {
	# server, msg, nick, addr, target
	on_message(@_, "message");
});

Irssi::signal_add("message private", sub {
	# server, msg, nick, addr
	on_message(@_, $_[0]->{nick}, "private");
});

Irssi::signal_add("message irc action", sub {
	# server, msg, nick, addr, target
	on_message(@_, "action");
});

Irssi::signal_add("message irc notice", sub {
	# server, msg, nick, addr, target
	on_message(@_, "notice");
});
