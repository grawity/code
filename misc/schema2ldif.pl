#!/usr/bin/env perl
# (c) 2012-2018 Mantas Mikulėnas <grawity@gmail.com>
# Released under the MIT License (dist/LICENSE.mit)
#
# Converts OpenLDAP schema from traditional slapd.conf format to LDIF format
# usable for importing into cn=config.

use warnings;
use strict;
use Getopt::Long qw(:config gnu_getopt no_ignore_case);

my $opt_replace = 0;
my $opt_unwrap = 0;

GetOptions(
	"r|replace!" => \$opt_replace,
	"unwrap!" => \$opt_unwrap,
) or exit(2);

if (-t STDIN) {
	warn "error: expecting a schema as stdin\n";
	exit(1);
}

my $name = shift(@ARGV) // "UNNAMEDSCHEMA";

print "dn: cn=$name,cn=schema,cn=config\n";
if ($opt_replace) {
	print "changetype: modify\n";
} else {
	print "objectClass: olcSchemaConfig\n";
}

my $key = "";
my $value;
my $count = 0;

while (<STDIN>) {
	chomp;
	if (/^(attributeType(?:s)?|objectClass(?:es)?) (.+)$/i) {
		my ($newkey, $newvalue) = ($1, $2);

		if ($newkey =~ /^attributeType(s)?$/i) {
			$newkey = "olcAttributeTypes";
		} elsif ($newkey =~ /^objectClass(es)?$/i) {
			$newkey = "olcObjectClasses";
		} else {
			$newkey = "olc$newkey";
		}

		if ($key) {
			print "$key: $value\n";
		}

		if ($opt_replace && lc($key) ne lc($newkey)) {
			print "-\n" if $count++;
			print "replace: $newkey\n";
		}

		($key, $value) = ($newkey, $newvalue);

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
