#!/usr/bin/env perl
# (c) 2012-2018 Mantas Mikulėnas <grawity@gmail.com>
# Released under the MIT License (dist/LICENSE.mit)
#
# Converts OpenLDAP schema from traditional slapd.conf format to LDIF format
# usable for importing into cn=config.

use warnings;
use strict;
use Getopt::Long qw(:config gnu_getopt no_ignore_case);

my $opt_unwrap = 0;

GetOptions(
	"unwrap!" => \$opt_unwrap,
) or exit(2);

if (-t STDIN) {
	warn "error: expecting a schema as stdin\n";
	exit(1);
}

my $name = shift(@ARGV) // "UNNAMEDSCHEMA";

print "dn: cn=$name,cn=schema,cn=config\n";
print "objectClass: olcSchemaConfig\n";

my $key;
my $value;

while (<STDIN>) {
	chomp;
	if (/^(attributeType(?:s)?|objectClass(?:es)?) (.+)$/i) {
		if ($key && $value) {
			print "$key: $value\n";
		}

		($key, $value) = ($1, $2);

		if ($key =~ /^attributeType(s)?$/i) {
			$key = "olcAttributeTypes";
		} elsif ($key =~ /^objectClass(es)?$/i) {
			$key = "olcObjectClasses";
		} else {
			$key = "olc$key";
		}
	}
	elsif (/^\s+(.+)$/) {
		if ($opt_unwrap) {
			$value .= " $1";
		} else {
			$value .= "\n $&";
		}
	}
	elsif (/^#.*/) {
		print "$&\n";
	}
	elsif (/.+/) {
		warn "$.:unrecognized input line: $&\n";
	}
}
if ($key && $value) {
	print "$key: $value\n";
}
