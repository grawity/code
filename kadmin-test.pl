#!/usr/bin/env perl
# Status: upstream bugs
# A::K::A->create_principal fails to use random keys (NULL as passwd)

use warnings;
use strict;
use Authen::Krb5;
use Authen::Krb5::Admin qw(:constants);

my $config = Authen::Krb5::Admin::Config->new;
$config->realm("NULLROUTE.EU.ORG");
$config->admin_server("virgule.cluenet.org");

my $client = 'grawity/admin@NULLROUTE.EU.ORG';
my $passwd = $ENV{TESTING_ADMIN_PW};

my $service = KADM5_ADMIN_SERVICE;

my $kadm5 = Authen::Krb5::Admin->init_with_password($client, $passwd, $service, $config)
// die Authen::Krb5::Admin::error;

my $princ = Authen::Krb5::parse_name('foo/bar@NULLROUTE.EU.ORG');

my $kadm_princ = Authen::Krb5::Admin::Principal->new;
$kadm_princ->principal($princ);
$kadm_princ->policy_clear();

$kadm5->create_principal($kadm_princ)
// die Authen::Krb5::Admin::error;
# Returns "Password is too short"

$kadm5->create_principal($kadm_princ, '')
// die Authen::Krb5::Admin::error;
# Returns "Password is too short"

$kadm5->create_principal($kadm_princ, undef)
// die Authen::Krb5::Admin::error;
# Warns "Use of uninitialized value in subroutine entry"
# Returns "Password is too short"

my @keys = $kadm5->randkey_principal($princ);
$kadm_princ = $kadm5->get_principal($princ);

my $keytab = Authen::Krb5::kt_resolve("FILE:foobie");
for my $keyblock (@keys) {
	my $ktentry = Authen::Krb5::KeytabEntry->new($princ, $kadm_princ->kvno, $keyblock);
	$keytab->add_entry($ktentry);
}
