#!/usr/bin/env perl
use warnings;
use strict;
use Data::Dumper;
use RPC::XML;
use RPC::XML::Client;
use XML::RPC;
use Nullroute::Lib;
use Nullroute::Sec;

my $api_creds = Nullroute::Sec::get_netrc("api/mail.utenos-kolegija.lt");

my $api_user = $api_creds->{login};
my $api_pass = $api_creds->{password};

my $root = "https://$api_user:$api_pass\@mail.utenos-kolegija.lt/rpc/";

my $cli = XML::RPC->new($root);

my $api_ptr = $cli->call("0->Create", "IceWarpServer.APIObject");
print "api $api_ptr\n";

my $domain_ptr = $cli->call($api_ptr."->OpenDomain", "utenos-kolegija.lt");
print "domain $domain_ptr\n";

my $acct_ptr = $cli->call($domain_ptr."->OpenAccount", "sospsrf");
print "acct $acct_ptr\n";

my $pass = $cli->call($acct_ptr."->GetProperty", "U_Password");
print "pass $pass\n";
