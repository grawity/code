#!perl
use warnings;
use strict;
use Irssi;
use POSIX;
use POSIX::strptime;

my %isreplaying;

my $replay_time_re = qr/^\[(\d\d:\d\d:\d\d)\] (.*)$/;

Irssi::signal_add_first("message public" => sub {
	my ($server, $msg, $nick, $addr, $target) = @_;
	my $tag = $server->{tag};
	if ($nick eq '***' && $addr eq 'znc@znc.in') {
		if ($msg =~ /^buffer playback/i) {
			$isreplaying{$tag}{$target} = 1;
			Irssi::signal_stop;
		} elsif ($msg =~ /^playback complete/i) {
			$isreplaying{$tag}{$target} = 0;
			Irssi::signal_stop;
		}
	} elsif ($msg ~~ $replay_time_re) {
		my ($msg_stamp, $text) = ($1, $2);
		my $time_fmt = Irssi::settings_get_str("timestamp_format");
		my @now_tm = localtime;
		my @msg_tm = POSIX::strptime($msg_stamp, "%H:%M:%S");
		map {$msg_tm[$_] //= $now_tm[$_]} 0..$#msg_tm;
		my $msg_tm = POSIX::strftime($time_fmt, @msg_tm);
		Irssi::settings_set_str("timestamp_format", $msg_tm);
		Irssi::signal_emit("setup changed");
		Irssi::signal_continue($server, $text, $nick, $addr, $target);
		Irssi::settings_set_str("timestamp_format", $time_fmt);
		Irssi::signal_emit("setup changed");
	}
});

Irssi::signal_add_first("server incoming" => sub {
	my ($server, $data) = @_;
	my $time_fmt;
	if ($data =~ /^@(\S+) (.+)$/) {
		my ($tags, $rest) = ($1, $2);
		my %tags = map {/^(.+)=(.*)$/ ? ($1,$2) : ($_,"")} split(/;/, $tags);
		if ($tags{time}) {
			$time_fmt = Irssi::settings_get_str("timestamp_format");
			my $msg_tm = POSIX::strftime($time_fmt, localtime $tags{time});
			Irssi::settings_set_str("timestamp_format", $msg_tm);
			Irssi::signal_emit("setup changed");
		}
		Irssi::signal_continue($server, $rest);
		if (defined $time_fmt) {
			Irssi::settings_set_str("timestamp_format", $time_fmt);
			Irssi::signal_emit("setup changed");
		}
	}
});
