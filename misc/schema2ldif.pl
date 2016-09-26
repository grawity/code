#!/usr/bin/env perl
# (c) 2012-2016 Mantas Mikulėnas <grawity@gmail.com>
# Released under the MIT License (dist/LICENSE.mit)

if (-t STDIN) {
	warn "error: expecting a schema as stdin\n";
	exit 1;
}

my $name = shift(@ARGV) // "UNNAMED";

print "dn: cn=$name,cn=schema,cn=config\n";
print "objectClass: olcSchemaConfig\n";
print "cn: $name\n";

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
			$key = 'olcAttributeTypes';
		} elsif ($key =~ /^objectClass(es)?$/i) {
			$key = 'olcObjectClasses';
		} else {
			$key = "olc$key";
		}
	}
	elsif (/^\s+(.+)$/) {
		$value .= "\n " . $_;
		#$value .= " " . $1;
	}
}
if ($key && $value) {
	print "$key: $value\n";
}
