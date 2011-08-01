#!/usr/bin/env perl
use warnings;
use strict;
use utf8;
use vars qw($VERSION %IRSSI);

use Irssi;
use Socket;
use IO::Socket::INET;
use IO::Socket::UNIX;
use List::MoreUtils qw(any);

$VERSION = "0.7.(0*ε)";
%IRSSI = (
	name        => 'notify-send',
	description => 'Sends hilight messages over DBus or Intertubes.',
	authors     => 'Mantas Mikulėnas',
	contact     => 'grawity@gmail.com',
	license     => 'WTFPL v2 <http://sam.zoy.org/wtfpl/>',
);

my $appname = "irssi";

my ($dbus, $libnotify);

my $dbus_error = 0;

my @hilights = (
	# Put regexps below, as per the example, just without the "#"

	# qr/whatever/i,
);

sub on_message {
	my ($server, $msg, $nick, $userhost, $target, $type) = @_;

	# Unfortunately, irssi only checks hilights at time of printing the
	# message, when such information as "nick" and "message" is effectively
	# lost in formatting. Even if we tried to regexp the sender's nick out
	# of the message, it would break with 60% of the themes out there.
	#
	# Besides, most people are fine with being notified when someone says
	# their name. The rest are welcome to modify the rules below.

	my $mynick = $server->{nick};
	my $channel = $server->ischannel($target);

	# skip server notices
	return if !defined $userhost;

	# if public, check for hilightness
	return if $channel and !(
		$msg =~ /\Q$mynick/i
		or any {$msg =~ $_} @hilights
	);

	# ignore notices from services
	return if !$channel and (
		($type eq "notice" and $userhost =~ /\@services/)
		or $nick =~ /^(nick|chan|memo|oper|php)serv$/i
	);

	my $tag = $channel ? $target : $nick;
	my $title = $nick;
	$title .= " on $target" if $channel;
	# filter funky characters; allow Tab (x09)
	$msg =~ s/[\x01-\x08\x0A-\x1F]//g;
	# send notification to all dests
	my $dests = Irssi::settings_get_str("notify_targets");
	foreach my $dest (split / /, $dests) {
		my @ret = notify($dest, $tag, $title, $msg);
		Irssi::print("Could not notify $dest: $ret[1]") if !$ret[0];
	}
}

sub xml_escape {
	$_ = shift; s/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; return $_;
}

sub getserv {
	my ($name, $proto) = @_;
	if ($name =~ /^[0-9]+$/) {
		return int $name;
	} else {
		my ($rname, $aliases, $port, $rproto) = getservbyname($name, $proto);
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

	if (!defined $dbus) {
		if (!defined $ENV{DISPLAY} and !defined $ENV{DBUS_SESSION_BUS_ADDRESS}) {
			use Data::Dumper;
			return $dbus_error++, "DBus session bus not available";
		}

		if (eval {require Net::DBus}) {
			$dbus = Net::DBus->session;
			$libnotify = $dbus->get_service("org.freedesktop.Notifications")
				->get_object("/org/freedesktop/Notifications");
		}
		else {
			return 0, "libnotify support requires Net::DBus";
		}
	}

	our %libnotify_state;
	my $state = $libnotify_state{$title} //= {};

	my $appname = $tag;
	my $icon = Irssi::settings_get_str("notification_icon");

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
	return 1;
}

sub send_growl {
	my ($title, $text) = @_;
	our $growl;
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
	my $port = getserv($service, $proto)
		or return 0, "Unknown service '$service/$proto'";
	my $sock;
	my %sock_args = (
		PeerAddr => $host,
		PeerPort => $port,
		Proto => $proto,
		Blocking => 0,
	);
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

sub send_inetssl {
	my ($data, $host, $service) = @_;
	my $port = getserv($service, "tcp")
		or return 0, "Unknown service '$service/tcp'";
	my $sock;
	my %sock_args = (
		PeerAddr => $host,
		PeerPort => $port,
		Proto => 'tcp',
		Blocking => 0,
		SSL_version => 'TLSv1',
		SSL_ca_path => '/etc/ssl/certs',
	);
	if (eval {require IO::Socket::SSL}) {
		$sock = IO::Socket::SSL->new(%sock_args);
	} else {
		return 0, "SSL support requires IO::Socket::SSL";
	}
	if (defined $sock) {
		print $sock $data;
		$sock->close();
		return 1;
	} else {
		return 0, $!;
	}
}

sub send_unix {
	my ($data, $type, $address) = @_;
	my $sock = IO::Socket::UNIX->new(
		Type => ($type eq 'stream'? SOCK_STREAM : SOCK_DGRAM),
		Peer => $address,
	);
	if (defined $sock) {
		print $sock $data;
		$sock->close();
		return 1;
	} else {
		return 0, $!;
	}
}

sub notify {
	my ($dest, $tag, $title, $text) = @_;

	my $icon = Irssi::settings_get_str("notification_icon");
	my $rawmsg = join("\x01", 2, $appname, $tag, $icon, $title, $text)."\n";

	if ($dest =~ /^(libnotify|dbus)$/) {
		send_dbus($tag, $title, $text);
	}
	elsif ($dest =~ /^file!(.+)$/) {
		send_file($rawmsg, $1);
	}
	elsif ($dest =~ /^growl$/) {
		send_growl($title, $text);
	}
	elsif ($dest =~ /^ssl!(.+?)!(.+?)$/) {
		send_inetssl($rawmsg, $1, $2);
	}
	elsif ($dest =~ /^(tcp|udp)!(.+?)!(.+?)$/) {
		send_inet($rawmsg, $1, $2, $3);
	}
	elsif ($dest =~ /^unix!(stream|dgram)!(.+)$/) {
		send_unix($rawmsg, $1, $2);
	}
	elsif ($dest =~ /^unix!(.+)$/) {
		send_unix($rawmsg, "stream", $1);
	}
	else {
		$dest =~ /^([^!]+)/;
		0, "Unsupported address type '$1'";
	}
}

Irssi::settings_add_str("libnotify", "notify_targets", "libnotify");
Irssi::settings_add_str("libnotify", "notification_icon", "avatar-default");

Irssi::signal_add "message public", sub {
	# server, msg, nick, addr, target
	on_message @_, "message"
};
Irssi::signal_add "message private", sub {
	# server, msg, nick, addr
	on_message @_, $_[0]->{nick}, "private"
};
Irssi::signal_add "message irc action", sub {
	# server, msg, nick, addr, target
	on_message @_, "action"
};
Irssi::signal_add "message irc notice", sub {
	# server, msg, nick, addr, target
	on_message @_, "notice"
};
