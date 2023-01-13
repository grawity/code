#!perl
use warnings;
use strict;
use Irssi;
use POSIX;
use POSIX::strptime;

# Note: Irssi does not allow signal handlers to override the event's
# time. Therefore, this script has to do something quite ugly -- that
# is, temporarily override your "timestamp_format" setting with the
# static time of the event.

# Note: This requires that you use cap_sasl, and manually modify it
# to also request the "znc.in/server-time" capability.

my %isreplaying;

my $replay_time_re = qr/^\[(\d\d:\d\d:\d\d)\] (.*)$/;
my $replay_time_fmt = "%H:%M:%S";

my $unix_time_re = qr/^\d+\.\d+$/;

my $iso_time_re = qr/^(\d+)-0*(\d+)-0*(\d+)T0*(\d+):0*(\d+):0*(\d+)(Z|[+-]\d+)$/;

my $iso_timezone_re = qr/^([+-])(\d{2})(\d{2})$/;

sub get_local_offset {
	my $t = time;
	my @a = localtime $t;
	my @b = gmtime $t;
	return ($a[2]-$b[2], $a[1]-$b[1]);
}

sub parse_time_tag {
	my ($str) = @_;
	if ($str =~ $unix_time_re) {
		localtime($str);
	} elsif (my @m = $str =~ $iso_time_re) {
		my ($hl, $ml) = get_local_offset();
		if ($m[6] =~ $iso_timezone_re) {
			my $mu = ($1 eq '+') ? 1 : -1;
			$hl -= $mu*int($2);
			$ml -= $mu*int($3);
		}
		($m[5], $m[4]+$ml, $m[3]+$hl, $m[2], $m[1]-1, $m[0]-1900);
	} else {
		();
	}
}

# Handle old-style <nick> [hh:mm:ss] timestamps

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
	} elsif ($msg =~ $replay_time_re) {
		my ($msg_stamp, $text) = ($1, $2);
		my $time_fmt = Irssi::settings_get_str("timestamp_format");
		my @now_tm = localtime;
		my @msg_tm = POSIX::strptime($msg_stamp, $replay_time_fmt);
		map {$msg_tm[$_] //= $now_tm[$_]} 0..$#msg_tm;
		my $msg_tm = POSIX::strftime($time_fmt, @msg_tm);
		Irssi::settings_set_str("timestamp_format", $msg_tm);
		Irssi::signal_emit("setup changed");
		Irssi::signal_continue($server, $text, $nick, $addr, $target);
		Irssi::settings_set_str("timestamp_format", $time_fmt);
		Irssi::signal_emit("setup changed");
	}
});

# Handle new-style "server-time" timestamps

Irssi::signal_add_first("server incoming" => sub {
	my ($server, $data) = @_;
	$data =~ /^@(\S+) (.+)$/ or return;
	my ($tags, $rest) = ($1, $2);
	my %tags = map {/^(.+)=(.*)$/ ? ($1,$2) : ($_,"")} split(/;/, $tags);
	my $time_fmt;
	if ($tags{time}) {
		$time_fmt = Irssi::settings_get_str("timestamp_format");
		my @msg_tm = parse_time_tag($tags{time});
		if (@msg_tm) {
			my $msg_tm = POSIX::strftime($time_fmt, @msg_tm);
			Irssi::settings_set_str("timestamp_format", $msg_tm);
			Irssi::signal_emit("setup changed");
			Irssi::signal_continue($server, $rest);
			Irssi::settings_set_str("timestamp_format", $time_fmt);
			Irssi::signal_emit("setup changed");
			return;
		}
	} 
	Irssi::signal_continue($server, $rest);
});
