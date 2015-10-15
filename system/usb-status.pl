#!/usr/bin/env perl
use warnings;
use strict;

sub readline {
    my ($file) = @_;
    if (open(my $fh, "<", $file)) {
        chomp(my $line = <$fh>);
        close($fh);
        return $line;
    } else {
        die "$!";
    }
}

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
    my $fmt = "%-*s  " x ($columns/2);
    $fmt =~ s/\s+$/\n/;
    printf $fmt, @items;
}

sub display_devices {
    my (@items) = @_;
    my %header = (
        dev_id => "ID",
        vendor => "MANUFACTURER",
        product => "PRODUCT",
        vp_name => "DEVICE",
    );
    my @fields = qw(dev_id vp_name);
    my %len = map {$_ => max(length($header{$_}),
                             maxlength($_, @items))} @fields;

    printrow(map {$len{$_}, $header{$_}} @fields);
    for my $i (@items) {
        printrow(map {$len{$_}, $i->{$_}} @fields;
    }
}

# vim: ts=4:sw=4:et
