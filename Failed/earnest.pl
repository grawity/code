#!/usr/bin/env perl
use warnings;
use strict;
use threads;
use threads::shared;

use JSON;
use Data::Dumper;
use LWP::Simple;
use List::MoreUtils qw(natatime);

my $data_dir = ($ENV{XDG_CONFIG_HOME} // $ENV{HOME}."/.config")."/ditch";

my @dmenu_opts = ("-fn", "Dina Bold 8", "-w", "-i", "-l", "40");

my $stream_quality = "medium,high,best,source";

my $v3_root = "https://api.twitch.tv/kraken";
my $v2_root = "http://api.twitch.tv/api";

sub fetch_json { decode_json(get(shift)); }

sub read_lines {
	my ($file) = @_;
	if (open(my $f, "<", $file)) {
		my @lines = grep {chomp || 1} <$f>;
		#my @lines;
		#while (my $line = <$f>) {
		#	chomp($f);
		#	push @lines, $f;
		#}
		close($f);
		return @lines;
	} elsif ($!{ENOENT}) {
		return;
	} else {
		warn "could not read '$file': $!\n";
		return;
	}
}

sub get_streamers {
	my @list;
	my ($user) = read_lines("$data_dir/username");
	if (defined $user) {
		my $data = fetch_json("$v3_root/users/$user/follows/channels");
		push @list,
			map {$_->{channel}->{name}}
			@{$data->{follows}};
	}
	my @streamers = read_lines("$data_dir/streamers");
	push @list, @streamers;
	push @list, 'starladder1';
	return @list;
}

sub get_teams {
	read_lines("$data_dir/teams");
}

sub get_all_streams {
	my @threads;

	print "[".threads->tid."] foo!\n";

	my $iter = natatime(100, get_streamers());
	#while (my @vals = $iter->()) {
	if (my @vals = get_streamers()) {
		push @threads, async {
			print "[".threads->tid."] get @vals\n";
			return qw(a b c);
			my $data = fetch_json("$v3_root/streams?channel=".join(",", @vals)."&limit=100");
			print "[".threads->tid."] done\n";

			map {[$_->{name}, $_->{url}, $_->{game}]}
			map {$_->{channel}}
			@{$data->{streams}};
		};
	}

	for my $team (get_teams()) {
		push @threads, async {
			print "[".threads->tid."] get $team\n";
			my $data = fetch_json("$v2_root/team/$team/live_channels");
			print "[".threads->tid."] done\n";

			map {[$_->{name}, $_->{link}, $_->{title}]}
			map {$_->{channel}}
			@{$data->{channels}};
		};
	}

	map {print "$_\n";$_->join()} @threads;
}

my @streams = get_all_streams();

for my $stream (@streams) {
	my ($name, $url, $title) = @$stream;

	print "$name [$url]: $title\n";
}
