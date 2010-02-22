#!/usr/bin/perl
# tweet.pl v1.0
# posts stuff to Twitter
#
# (c) 2009 Mantas Mikulėnas <grawity@gmail.com>
# Released under WTFPL v2 <http://sam.zoy.org/wtfpl/>

use warnings;
use strict;

use Getopt::Long;
use Net::Netrc;
use LWP::UserAgent;
use XML::Simple;

sub msg_usage {
	print STDERR "Usage: tweet [-u user] [-p password] [-r tweet_id] text\n";
	return 2;
}
sub msg_help {
	print q{Usage: tweet [-u user] [-p password] [-r tweet_id] text

  -u  Twitter account (username) to use, if multiple entries
      exist in ~/.netrc (otherwise the first match is used)
  -p  Twitter password (if you are careless enough to do this)
  -r  post a reply to this tweet ID (mostly for scripts)

When replying to another tweet, the reply must start with "@username", where
'username' = author of the original tweet. Otherwise Twitter will reject it.

When using -p, remember that the entire command line will be visible in the
output of 'ps' and other commands, also in your ~/.history file.

The .netrc file format is described in the manual page of ftp(1).
};
	return 0;
}

sub lookup_authdata {
	my ($user) = @_;
	my $netrc = Net::Netrc->lookup("twitter.com", $user);
	return defined($netrc->{machine}) ? ($netrc->login, $netrc->password) : ();
}

sub post_tweet {
	my ($text, $user, $pass, $replyid) = @_;

	my $ua = LWP::UserAgent->new();
	$ua->credentials("api.twitter.com:443", "Twitter API", $user, $pass);

	my %data = (status => $text);

	if (defined $replyid) {
		die "Replies must start with \@username\n" if $text !~ /^\@[^ ]+ /;
		# ...otherwise Twitter rejects them.

		$data{"in_reply_to_status_id"} = $replyid;
	}

	my $resp = $ua->post("https://api.twitter.com/1/statuses/update.xml", \%data);
	return XMLin($resp->decoded_content);
}

my ($user, $pass, $replyid, $text);
GetOptions(
	"u=s" => \$user,
	"p=s" => \$pass,
	"r=i" => \$replyid,
	"h|help" => sub { exit msg_help },
) or exit msg_usage;

$text = shift @ARGV or exit msg_usage;

if (length $text > 140) {
	print STDERR length($text)." character tweet is too long\n";
	exit 1;
}

if (!defined $user or !defined $pass) {
	($user, $pass) = lookup_authdata($user);
}
if (!defined $user or !defined $pass) {
	print STDERR "Login information for twitter.com not found in ~/.netrc\n";
	exit 3;
}

my $tweet = post_tweet($text, $user, $pass, $replyid);

if (defined $tweet->{error}) {
	print "Twitter error: ".$tweet->{error}."\n";
	exit 1;
}
else {
	my $id = $tweet->{id};
	my $real_user = $tweet->{user}->{screen_name};
	my $real_text = $tweet->{text};
	my $post_url = "https://twitter.com/${real_user}/status/${id}";
	print "$post_url\n";
	print "<$real_user> $real_text\n";
}
