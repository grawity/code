# Parser for IRC protocol messages (RFC 1459 + IRCv3 message-tag extension)
#
# (c) 2012-2014 Mantas Mikulėnas <grawity@gmail.com>
# Released under the MIT Expat License (dist/LICENSE.expat)

package Nullroute::IRC;
use warnings;
use strict;

sub split_line {
	my ($str) = @_;
	chomp($str);
	my @vec = split(/ /, $str, -1);
	my ($i, $n) = (0, scalar @vec);
	my ($tags, $prefix, @argv);
	while ($i < $n && !length($vec[$i])) {
		++$i;
	}
	if ($i < $n && $vec[$i] =~ /^@/o) {
		push @argv, $vec[$i];
		++$i;
		while ($i < $n && !length($vec[$i])) {
			++$i;
		}
	}
	if ($i < $n && $vec[$i] =~ /^:/o) {
		push @argv, $vec[$i];
		++$i;
		while ($i < $n && !length($vec[$i])) {
			++$i;
		}
	}
	while ($i < $n) {
		if ($vec[$i] =~ /^:/) {
			last;
		} elsif (length($vec[$i])) {
			push @argv, $vec[$i];
		}
		++$i;
	}
	if ($i < $n) {
		my $trailing = join(" ", @vec[$i..$#vec]);
		push @argv, substr($trailing, 1);
	}
	return @argv;
}

1;
