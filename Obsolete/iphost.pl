#!perl
use strict;
use Net::LDAP;
use Authen::SASL;
use feature 'say';

my $con = Net::LDAP->new("ldap.cluenet.org");
my $sasl = Authen::SASL->new(mech => "GSSAPI");
my $sasl_client = $sasl->client_new("ldap", "radian.cluenet.org");
$con->bind(sasl => $sasl_client);

my $res = $con->search(base => "ou=servers,dc=cluenet,dc=org",
		scope => "one",
		filter => q[(|(ipAddress=*)(ipv6Address=*))],
		attrs => ["ipAddress", "ipv6Address"]);

for my $entry ($res->entries) {
	say "dn: ".$entry->dn;

	my $addr = $entry->get_value("ipAddress");
	if ($addr =~ /^[a-z.]+$/) {
		say "moving: $addr";
		my $r = $con->modify($entry->dn,
			add => {ipHostNumber => $addr},
			delete => {ipAddress => $addr});
		say $r->error if $r->is_error;
	} else {
		say "skipping: $addr";
	}

	print "\n";
}
