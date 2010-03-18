# vim: ft=perl
use warnings;
use strict;
use Irssi;
use vars qw($VERSION %IRSSI);

$VERSION = "1.2.constantly-evolving";
%IRSSI = (
	authors     => 'grawity',
	contact     => 'grawity@gmail.com',
	name        => 'spamfilter',
	description => 'Automatically ignores messages matching certain patterns.',
	license     => 'WTFPL 2.0 <http://sam.zoy.org/wtfpl/>',
	url         => 'http://purl.oclc.org/NET/grawity/irssi.html',
);

use Data::Dumper;

my $logfile = Irssi::get_irssi_dir() . "/autoignore.log";

my @blocked = ();

sub block(@) {
	for my $mask (@_) {
		push @blocked, $mask;
		Irssi::print "Added $mask to session ignore";
	}
	return 1;
}

sub test(@) {
	my ($server, $msg, $nick, $userhost, $target, $type) = @_;

	my ($user, $host) = split "!", $userhost, 2;

	my $ispublic = $server->ischannel($target);

	#my ($channel, $userinfo);
	#if ($ispublic and $target ne "") {
	#	$channel = $server->channel_find($target);
	#	if (defined $channel) {
	#		$userinfo = $channel->nick_find($nick);
	#	}
	#}

	return 1 if ignorelisted($server, $nick, $userhost);

	return 0 if (
		# ($ispublic and $userinfo->{op})
		($ispublic and lc($target) eq '#xkcd')
		or $nick eq 'Bucket'
	);

	return block "*!$userhost" if (
		$msg =~ /^Transmitting virus\.\.\.$/
		or $nick =~ /shit|feces/i
		or $msg =~ /^.{0,3}DCC SEND "/
		or $msg =~ /^[0-9A-Za-z]{64}$/
		or $msg =~ /RIZON\.NET/
		or $msg =~ /(tomaw|kloeri|christel).*dick/i
		or $msg =~ /(HA){3,}/
		or $msg =~ /FUCK OFF/
		or $msg =~ /http:\/\/AnonTalk\.com/
		or $msg =~ /^i have to take a dump/i
		or ($type eq 'action' and $msg =~ /^shits$/i)
	);

	return 1 if (
		($ispublic and $type =~ /^notice|dcc|ctcp|ctcpreply$/)
		or ($type eq 'dcc' and $msg =~ /.MPEG$/)
		or $msg =~ /[^\w](faggot|cunt|nigger)/i
		or $msg =~ /^fuck you/i
		or $msg =~ /#[A-Z]{5,}([^A-Za-z0-9]|$)/
		or $msg =~ /^~HAPPY NEW YEARS!!!~$/
		or $msg =~ /IRC\..+\.COM/
		or ($ispublic and hilightspam_score($server, $target, $msg) > 0.8)
	);

	return 0;
}

sub ignorelisted($$$) {
	my ($server, $nick, $userhost) = @_;
	return grep { $server->mask_match_address($_, $nick, $userhost) } @blocked;
}

# RFC-compatible lc()
sub lci($) { my $_ = shift; tr/\[\\\]^/{|}~/; return lc $_; }

sub on_message(@$) {
	my ($server, $msg, $nick, $userhost, $target, $type) = @_;

	return if !defined $userhost; # skip server notices

	my $public = $server->ischannel($target);

	if (test @_) {
		Irssi::signal_stop;
		open LOG, ">> $logfile";
		print LOG (join "|", ($server->{tag}, "$nick!$userhost", $target, $type, $msg))."\n";
		close LOG;
		return 1;
	}
	return 0;
}


Irssi::signal_add_first "message public" => sub {
	on_message @_, "message"
};
Irssi::signal_add_first "message private" => sub {
	my $server = $_[0];
	on_message @_, $server->{nick}, "message"
};
Irssi::signal_add_first "message irc notice" => sub {
	on_message @_, "notice"
};
Irssi::signal_add_first "ctcp msg" => sub {
	# actions are handled by "ctcp action"
	on_message @_, "ctcp" unless $_[1] =~ /^ACTION /i;
};
Irssi::signal_add_first "ctcp reply" => sub {
	on_message @_, "ctcpreply";
};
Irssi::signal_add_first "ctcp action" => sub {
	on_message @_, "action";
};
Irssi::signal_add_first "dcc request" => sub {
	my ($dccrec, $addr) = @_;

	$dccrec->destroy() if on_message $dccrec->{server}, $dccrec->{arg}, $dccrec->{nick},
		$addr, $dccrec->{target}, "dcc", $dccrec;
};

Irssi::command_bind "blocklist" => sub {
	my ($args, $server, $witem) = @_;

	if ($args ne '') {
		map { push @blocked, $_; Irssi::print "Adding $_ to session blocklist" } split / /, $args;
		return;
	}

	my $count = $#blocked + 1;
	Irssi::print "Session blocklist has $count entries.";
	my $i = 0;
	for my $entry (@blocked) {
		printf "%3d  %s", $i++, $entry;
	}
};

Irssi::command_bind "hscore" => sub {
	my ($args, $server, $witem) = @_;
	my $score = hilightspam_score($server, $witem->{name}, $args);
	print "Hilightspam score: $score";
};

sub hilightspam_score {
	my ($server, $target, $msg) = @_;
	my $channel = $server->channel_find($target);
	my @nicks = $channel->nicks();

	$msg =~ s/^(<.+?>| \* .+?) //;
	my @msg = split / +/, $msg;

	my $word_count = $#msg+1;
	return 0 if $word_count < 4;
	my $msg_len = length $msg;
	my $hilight_count = 0;

	foreach my $n (@nicks) {
		$n = $n->{nick};
		#$n =~ s![*?+\[\]()\{\}\^\$\|\\]!\\$&!;
		$hilight_count++ if grep { $_ =~ m/^[@+]?\Q$n\E$/i } @msg;
	}

	my $score = $hilight_count / $word_count;
	return $score;
}
