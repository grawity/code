#!/usr/bin/perl
# tweet.pl v1.1
# posts stuff to Twitter
#
# (c) 2009 Mantas Mikulėnas <grawity@gmail.com>
# Released under WTFPL v2 <http://sam.zoy.org/wtfpl/>

use warnings;
use strict;

binmode STDOUT, ":utf8";

use Getopt::Long;
use Net::Netrc;
use LWP::UserAgent;
use XML::Simple;
use Data::Dumper;

sub msg_usage {
	print STDERR "Usage: tweet [-u user] [-p password] [-r tweet_id] text\n";
	return 2;
}
sub msg_help {
	print
q{Usage: tweet [-u user] [-p password] [-r tweet_id] text

  -u  Twitter account (username)
  -p  Twitter password (must be used with -u)
  -r  reply to this tweet ID (must start with "@username")

The .netrc file format is described in the manual page of ftp(1).
};
	return 0;
}

sub lookup_auth {
	my ($user) = @_;
	my $netrc = Net::Netrc->lookup("twitter.com", $user);
	return defined($netrc->{machine}) ? ($netrc->login, $netrc->password) : ();
}

sub get {
	my ($ua, $url) = @_;
	my $resp = $ua->get("https://api.twitter.com/1/${url}.xml");
	return XML::Simple::XMLin($resp->decoded_content);
}

sub post {
	my ($ua, $url, $data) = @_;
	my $resp = $ua->post("https://api.twitter.com/1/${url}.xml", $data);
	return XML::Simple::XMLin($resp->decoded_content);
}

my ($text, $replyid, $user, $pass);
GetOptions(
	"u=s" => \$user,
	"p=s" => \$pass,
	"r=i" => \$replyid,
	"h|help" => sub { exit msg_help },
) or exit msg_usage;

if (!defined $user or !defined $pass) {
	($user, $pass) = lookup_auth($user);
}
if (!defined $user or !defined $pass) {
	print STDERR "error: twitter.com not found in ~/.netrc\n";
	exit 3;
}

my $ua = LWP::UserAgent->new();
$ua->credentials("api.twitter.com:443", "Twitter API", $user, $pass);

$text = shift @ARGV;

if (defined $text) {
	if (length($text) > 140) {
		print STDERR "error: tweet too long (".length($text)." chars)\n";
		exit 1;
	}
	my %data = (status => $text);

	if (defined $replyid) {
		die "Replies must start with \@username\n"
			if $text !~ /^\@[^ ]+ /;
		# ...otherwise Twitter rejects them.
		$data{"in_reply_to_status_id"} = $replyid;
	}

	my $resp = post $ua, "statuses/update", \%data;
	if (defined $resp->{error}) {
		print STDERR "error: Twitter: ".$resp->{error}."\n";
		exit 1;
	}
}
else {
	my $resp = get $ua, "statuses/home_timeline";
	if (defined $resp->{error}) {
		print STDERR "error: Twitter: ".$resp->{error}."\n";
		exit 1;
	}

	for my $id (reverse keys %{$resp->{status}}) {
		my $status = $resp->{status}->{$id};
		printf "<\e[1m%s\e[m> %s\n", $status->{user}->{screen_name}, $status->{text};
	}
}
