use warnings;
use strict;
use Irssi;
use vars qw($VERSION %IRSSI);
use XML::Simple;

$VERSION = "0.1";
%IRSSI = (
	name		=> 'mail_notification wrapper',
	description	=> 'A wrapper for the mail-notification tray app',
	authors		=> 'grawity',
	contact		=> 'grawity@gmail.com',
	license		=> 'WTFPL v2 <http://sam.zoy.org/wtfpl/>',
	url			=> 'http://purl.net/NET/grawity/',
);

my @seen = ();

sub check() {
	my $w = Irssi::active_win();

	open my $fd, "-|", "mail-notification", "-s";
	my $data = XMLin($fd,
		ForceArray => ["message"]
		);

	for my $message_id (keys %{$data->{message}}) {
		my $msg = $data->{message}->{$message_id};
		# $msg->{from, subject, mailbox, sent_time, new}

		next if grep {$_ eq $message_id} @seen;

		$w->print("Mail from $msg->{from}:");
		$w->print("    $msg->{subject}");

		push @seen, $message_id;
	}
}

sub add_timer() {
	my $interval = Irssi::settings_get_int("mail_check_interval");

	if ($interval > 0) {
		return Irssi::timeout_add($interval*1000, \&check, undef);
	} else {
		return 0;
	}
}


Irssi::settings_add_int("mail_notification", "mail_check_interval", 5);

my $timer = add_timer();

Irssi::signal_add("setup changed", sub {
	if ($timer) {
		Irssi::timeout_remove($timer);
	}
	$timer = add_timer();
});

Irssi::command_bind("mail", sub {
	my ($args, $server, $window) = @_;
	if ($args eq '-all') {
		@seen = ();
	}
	check();
});

check();
