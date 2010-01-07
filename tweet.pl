#!/usr/bin/perl
# tweet.pl v1.0
# posts stuff to Twitter
#
# (c) 2009 Mantas Mikulėnas <grawity@gmail.com>
# Released under WTFPL v2 <http://sam.zoy.org/wtfpl/>

use warnings;
use strict;
use utf8;

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

my ($user, $pass, $replyid, $text);
GetOptions(
	"u=s" => \$user,
	"p=s" => \$pass,
	"r=i" => \$replyid,
	"h|help" => sub { exit msg_help },
) or exit msg_usage;

$text = shift @ARGV or exit msg_usage;

if (length $text > 140) {
	print STDERR (length $text)." character tweet is too long\n";
	exit 1;
}

# get Twitter credentials from ~/.netrc if not given
if (!defined $user or !defined $pass) {
	my $authdata = Net::Netrc->lookup("twitter.com", $user);
	if (!defined $authdata or !defined $authdata->{machine}) {
		die "Authentication data not found in ~/.netrc\n";
	}
	# password given in @ARGV overrides netrc
	$user = $authdata->login;
	$pass = $authdata->password unless defined $pass;
}

sub post_tweet {
	my ($text, $user, $pass, $replyid) = @_;

	my $ua = LWP::UserAgent->new();
	$ua->credentials("twitter.com:443", "Twitter API", $user, $pass);

	my %data = ( status => $text );

	if (defined $replyid) {
		die "Replies must start with \@username\n" if $text !~ /^\@[^ ]+ /;
		# ...otherwise Twitter rejects them.

		$data{"in_reply_to_status_id"} = $replyid;
	}

	my $resp = $ua->post("https://twitter.com/statuses/update.xml", \%data);
	return XMLin($resp->decoded_content);
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
	print "<$real_user> $real_text\n";
	print "at $post_url\n";
}
