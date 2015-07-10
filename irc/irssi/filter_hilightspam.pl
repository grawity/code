# vim: ft=perl
use strict;
use Irssi;
use vars qw($VERSION %IRSSI);

$VERSION = "1.4";
%IRSSI = (
	name        => 'filter_hilightspam',
	description => 'Blocks messages consisting of too many nicknames.',
	authors     => 'grawity',
	contact     => 'grawity@gmail.com',
	license     => 'WTFPL v2 <http://sam.zoy.org/wtfpl/>',
	url         => 'http://purl.net/NET/grawity/',
);

use Data::Dumper;

sub on_message {
	my ($server, $msg, $nick, $userhost, $target, $type) = @_;

	my $treshold = 0.8;

	return if !defined $userhost;           # skip server notices
	return if !$server->ischannel($target); # and private messages

	my $channel = $server->channel_find($target);
	if (!defined $channel) {
		print "$IRSSI{name}: error: channel_find($target) returned undef";
		print "failed on message: >$target< $msg";
		return 0;
	}
	my @nicks = $channel->nicks();

	if (hilightspam_score($msg, \@nicks) > $treshold) {
		Irssi::signal_stop;
		return 1;
	}
}

sub hilightspam_score {
	my ($msg, $nicks) = @_;

	$msg =~ s/^(<.+?>| \* .+?) //;
	my @msg = split / +/, $msg;

	my $word_count = $#msg+1;
	return 0 if $word_count < 4;
	my $msg_len = length $msg;
	my $hilight_count = 0;

	foreach my $n (@$nicks) {
		$n = $n->{nick};
		#$n =~ s![*?+\[\]()\{\}\^\$\|\\]!\\$&!;
		$hilight_count++ if grep { $_ =~ m/^[\@+]?\Q$n\E$/i } @msg;
	}
	my $score = $hilight_count > 6;
	return $score;
}

Irssi::signal_add_first "message public" => sub {
	on_message @_, "message";
};
Irssi::signal_add_first "message irc notice" => sub {
	on_message @_, "notice";
};
Irssi::signal_add_first "ctcp action" => sub {
	on_message @_, "action";
};

Irssi::command_bind "hscore" => sub {
	my ($args, $server, $witem) = @_;
	my $itemname = $witem->{name};
	if (!defined $itemname or !$server->ischannel($itemname)) {
		$witem->print("Cannot calculate hilight score for non-channels");
		return;
	}
	my @nicks = $server->channel_find($itemname)->nicks();
	my $score = hilightspam_score($args, \@nicks);
	$witem->print("Hilightspam: line scored $score for $itemname");
};
