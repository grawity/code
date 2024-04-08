#!/usr/bin/env perl
# (c) 2012-2018 Mantas Mikulėnas <grawity@gmail.com>
# Released under the MIT License (dist/LICENSE.mit)
#
# Converts OpenLDAP schema from traditional slapd.conf format to LDIF format
# usable for importing into cn=config.

use warnings;
use strict;
use Getopt::Long qw(:config gnu_getopt no_ignore_case);

sub show_help {
	print "Usage: $0 [-r|--replace] [-u|--unwrap] <schema_name>\n";
	return 2;
}

my $opt_name;
my $opt_dn;
my $opt_replace = 0;
my $opt_unwrap = 0;
my $opt_mode = "openldap";

GetOptions(
	"r|replace!" => \$opt_replace,
	"u|unwrap!" => \$opt_unwrap,
) or exit(show_help());

if (-t STDIN) {
	warn "error: expecting a schema as stdin\n";
	exit(1);
}

$opt_name //= shift(@ARGV) // "UNNAMEDSCHEMA";
$opt_dn //= "cn=$opt_name,cn=schema,cn=config";

print "dn: $opt_dn\n";
if (!$opt_replace) {
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
		next;
	}
	elsif (/.+/) {
		warn "$.:unrecognized input line: $&\n";
	}
}
if ($key && $value) {
	print "$key: $value\n";
}
