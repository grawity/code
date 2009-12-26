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

my $logfile = Irssi::get_irssi_dir() . "/autoignore.log";

my @blocked = ();

sub test {
	my ($server, $msg, $nick, $userhost, $target, $type, $subtype) = @_;
	my ($user, $host) = split '@', $userhost;
	my $network = $server->{tag};
	#my $isprivate = $target =~ /^[#&+!]/;
	my $ispublic = $server->ischannel($target);
	my ($channel, $userinfo);
	if ($ispublic) {
		$channel = $server->channel_find($target) or print "SOMETHING WENT WRONG: $ispublic $target";
		$userinfo = $channel->nick_find($nick) if defined $channel;
	}

	return 1 if ignorelisted($server, $nick, $userhost);

	return 0 if (
		($ispublic and $userinfo->{op})
		or ($ispublic and lc($target) eq '#xkcd')
		or $nick eq 'Bucket'
	);

	do { push @blocked, "*!$userhost"; return 1 } if (
		$msg =~ /^Transmitting virus\.\.\.$/
		or $nick =~ /dump|shit|feces/i
		or $msg =~ /^.{0,3}DCC SEND "/
		or $msg =~ /^[0-9A-Za-z]{64}$/
		or $msg =~ /RIZON\.NET/
		or $msg =~ /(tomaw|kloeri|christel).*dick/i
		or $msg =~ /(HA){3,}/
		or $msg =~ /FUCK OFF/
	);

	return 1 if (
		($ispublic and $type =~ /^notice|dcc|ctcp$/)
		or ($type eq 'dcc' and $msg =~ /.MPEG$/)
		or $msg =~ /[^\w](faggot|cunt|nigger)/i
		or $msg =~ /^fuck you/i
		or $msg =~ /#[A-Z]{5,}([^A-Za-z0-9]|$)/
		or $msg =~ /http:\/\/AnonTalk\.com/
		or ($ispublic and hilightspam_score($server, $target, $msg) > 0.8)
	);
}

# TODO: check irssi ignore list too
# TODO: find out whether 'message *' trigger for irssi-ignored messages
sub ignorelisted($$$) {
	my ($server, $nick, $userhost) = @_;
	return grep { $server->mask_match_address($_, $nick, $userhost) } @blocked;
}

sub on_message {
	my ($server, $msg, $nick, $userhost, $target, $type, $subtype) = @_;
	return if !defined $userhost; # skip server notices

	if (!defined $subtype) { $subtype = $server->ischannel($target)? "public" : "private"; }

	if (test @_) {
		Irssi::signal_stop;
		open LOG, ">> $logfile";
		print LOG (join "|", ($server->{tag}, "$nick!$userhost", $target, "$type:$subtype", $msg))."\n";
		close LOG;
		return 1;
	}
	return 0;
}

sub lc_i { my $_ = shift; tr/\[\\\]^/{|}~/; return lc $_; }

Irssi::signal_add_first "message public" => sub {
	on_message @_, "message", "public"
};
Irssi::signal_add_first "message private" => sub {
	on_message @_, "message", "private"
};
Irssi::signal_add_first "message irc action" => sub {
	on_message @_, "action"
};
Irssi::signal_add_first "message irc notice" => sub {
	on_message @_, "notice"
};
Irssi::signal_add_first "message irc ctcp" => sub {
	on_message @_, "ctcp"
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
		$hilight_count++ if grep { $_ eq $n->{nick} } @msg;
	}

	my $score = $hilight_count / $word_count;
	return $score;
}
