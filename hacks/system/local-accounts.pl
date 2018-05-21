#!/usr/bin/env perl
use List::Util qw(max);

sub maxlength {
	my ($attr, @items) = @_;
	(max map {length $_->{$attr}} @items) // 0;
}

sub printrow {
	my (@items) = @_;
	my $columns = @items;
	if ($columns % 2) {
		warn "Odd number of items";
		pop @items;
		--$columns;
	}
	my $fmt = "%*s  " x ($columns/2);
	$fmt =~ s/\s+$/\n/;
	printf $fmt, @items;
}

my @items;

open my $f, "<", "/etc/passwd";

while (<$f>) {
	chomp;
	my @F = split /:/;
	push @items, {
		name => $F[0],
		passwd => $F[1],
		uid => $F[2],
		gid => $F[3],
		gecos => $F[4],
		dir => $F[5],
		shell => $F[6]};
}

my @fields = qw(name uid gid gecos dir shell);

my %length = map {$_ => maxlength($_, @items)} @fields;

$length{$_} = 0 - $length{$_} for qw(name gecos dir shell);

for my $item (@items) {
	printrow map {$length{$_}, $item->{$_}} @fields;
}
