# vim: ft=perl
use warnings;
use strict;
use Irssi;
use vars qw($VERSION %IRSSI);

$VERSION = "1.3.constantly-evolving";
%IRSSI = (
	name        => 'filter_junk',
	description => 'Automatically ignores messages matching certain patterns.',
	authors     => 'grawity',
	contact     => 'grawity@gmail.com',
	license     => 'WTFPL 2.0 <http://sam.zoy.org/wtfpl/>',
	url         => 'http://purl.net/NET/grawity/',
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

	return block "*!$userhost" if (0
		or $nick =~ /shit|feces/i
		or $msg =~ /^.{0,3}DCC SEND "/
		or $msg =~ /^[0-9A-Za-z]{64}$/
		or $msg =~ /RIZON\.NET/
	);

	return 1 if (0
		or ($ispublic and $type =~ /^notice|dcc|ctcp|ctcpreply$/)
		or ($type eq 'dcc' and $msg =~ /.MPEG$/)
		or $msg =~ /[^\w](faggot|cunt|nigger)/i
		or $msg =~ /^fuck you/i
		or $msg =~ /#[A-Z]{5,}([^A-Za-z0-9]|$)/
		or $msg =~ /IRC\..+\.COM/
	);

	return 0;
}

sub ignorelisted($$$) {
	my ($server, $nick, $userhost) = @_;
	return grep { $server->mask_match_address($_, $nick, $userhost) } @blocked;
}

# RFC 1459-compatible lc()
sub lci($) { my $s = shift; $s =~ tr/\[\\\]/{|}/; return lc $s; }

sub on_message {
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
