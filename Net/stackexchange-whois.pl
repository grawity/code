#!/usr/bin/env perl
use utf8;
use warnings;
use strict;
use v5.16;
use JSON;
use LWP::UserAgent;
use Data::Dumper;

my $LWP = LWP::UserAgent->new;
my $JSON = JSON->new;

sub do_row {
	my ($key, @val) = @_;
	my $i = 0;
	for my $val (@val) {
		printf "%-20s: %s\n", $i++ ? "" : $key, $val;
	}
}

sub whois_stackexchange {
	my ($user, $domain) = @_;
	my $APIROOT = "http://api.stackexchange.com/2.1";
	my $rep = $LWP->get("$APIROOT/users/$user?site=$domain");
	if ($rep->is_success) {
		my $all = $JSON->decode($rep->decoded_content);
		my $user = $all->{items}->[0];
		return $user;
	}
}

my $user = whois_stackexchange(@ARGV);

sub Δ {
	my $n = shift; ($n > 0 ? "+" : "") . $n;
}

do_row user_id => (
	"local ".$user->{user_id},
	"global ".$user->{account_id},);
do_row user_type => $user->{user_type};
do_row user_created => $user->{creation_date};
do_row user_last_login => $user->{last_access_date};
do_row display_name => $user->{display_name};
do_row profile_url => $user->{link};
do_row linked_url => $user->{website_url};
do_row reputation => $user->{reputation};
do_row rep_delta => (
	"year ".Δ($user->{reputation_change_year}),
	"quarter ".Δ($user->{reputation_change_quarter}),
	"month ".Δ($user->{reputation_change_month}),
	"week ".Δ($user->{reputation_change_week}),
	"day ".Δ($user->{reputation_change_day}),);
