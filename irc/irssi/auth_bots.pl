# vim: ft=perl
use warnings;
use strict;
use Irssi;
use vars qw($VERSION %IRSSI);
$VERSION = "1.0.1";
%IRSSI = (
	authors     => "Mantas Mikulėnas",
	contact     => 'grawity@gmail.com',
	name        => 'auth_bots',
	description => 'Lets you authenticate to various IRC bots easily.',
	license     => 'WTFPL v2 <http://sam.zoy.org/wtfpl/>',
	url         => 'http://purl.net/net/grawity/irssi.html',
);

my @authinfo = ();
my $authfile = Irssi::get_irssi_dir() .  "/bots.auth";

# Format of bots.auth:
#   servertag/botnick bottype username password
# 
# Example:
#   freenode/phrik supybot grawity passw3rd
# This will allow you to /botauth phrik, on Freenode.
# (phrik's the #archlinux bot, if you are wondering)
#
# Use /botauth -load, to reload bots.auth
#
# Server tags are case-insensitive. Bot nicks are case-insensitive, and [\]^
# are treated as identical to {|}~ (according to RFC 2812 and most ircds)

# "identify %p", p => "hunter2" --> "identify hunter2"
sub fmt {
	my ($str, %data) = @_;
	$data{"%"} = "%";
	$str =~ s/(%(.))/exists $data{$2}? (defined $data{$2}? $data{$2} :"") : $1/ge;
	return $str;
}

my %authcommands = (
	Default	=> "identify %u %p",

	anope	=> "identify %p",
	atheme	=> "identify %u %p",
	eggdrop	=> "ident %p",
	phpserv	=> "identify %u %p",
	supybot	=> "identify %u %p",
	ubbm	=> "login %u %p",
);

# convert to lowercase with IRC extensions
sub lci {
	my ($str, $map) = @_;
	if ($map eq 'rfc1459') { $str =~ tr/\[\\\]/{|}/; }
	if ($map eq 'rfc2812') { $str =~ tr/\[\\\]^/{|}~/; }
	return lc $str;
}

# search for authinfo by servertag/botnick
sub grep_authinfo {
	my ($tag, $botnick, $casemap) = @_;
	$tag = lc $tag;
	$botnick = lci $botnick, $casemap;
	
	for my $entry (@authinfo) {
		my @entry = split " ", $entry, 4;
		my ($e_tag, $e_botnick) = split "/", (shift @entry), 2;
		return @entry if (lc $e_tag eq $tag)
			and (lci $e_botnick, $casemap eq $botnick);
	}
	return (undef, undef, undef);
}

sub load_info {
	@authinfo = ();
	open my $file, "<", $authfile;
	while (<$file>) {
		chomp;
		push @authinfo, $_;
	}
	close $file;
}

Irssi::command_bind "botauth" => sub {
	my ($args, $server, $witem) = @_;
	
	if ($args eq "-add") {
		my ($foo, $bot, $type, $user, $pass) = split / /, $args, 5;
		$foo = join " ", $bot, $type, $user, $pass;
		push @authinfo, $foo;

		umask 077;
		open my $file, ">>", $authfile;
		print $file "$foo\n";
		close $file;
		return;
	}
	elsif ($args eq "-load") {
		load_info;
		return;
	}

	my ($botnick) = split / /, $args;
	my $casemap = $server->isupport("CASEMAPPING") // "rfc1459";
	my ($type, $user, $pass) = grep_authinfo $server->{tag}, $botnick, $casemap;
	if (!defined $type) {
		Irssi::print "No creds set for ".$server->{tag}."/".$botnick;
		return;
	}
	my $command = defined $authcommands{$type}
		? $authcommands{$type}
		: $authcommands{"Default"};
	my $msg = fmt $command, (
		"u" => $user,
		"p" => $pass,
		"n" => $server->{nick},
		"N" => $server->{wanted_nick},
	);
	$server->print("", "Authenticating to $botnick");
	$server->send_message($botnick, $msg, 1);
};

load_info();
