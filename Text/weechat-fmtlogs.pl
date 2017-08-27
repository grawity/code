#!/usr/bin/env perl
# vim: ts=4:sw=4:et

sub fmt {
    my ($str, $color) = @_;
    if ($color) { "\e[38;5;".$color."m".$str."\e[m"; } else { $str; }
}

while (<>) {
    my ($f_time, $f_prefix, $f_msg) = split(/\t/, $_, 3);

    my $c_prefix = 76;
    my $c_msg = 0;

    if ($f_prefix eq " *") {
        $c_prefix = 196;
        $c_msg = 208;
    }
    elsif ($f_prefix !~ /[A-Za-z0-9_]/ || $f_prefix eq "-i-") {
        $c_msg = 66;
    }

    print fmt($f_time, 239), " ",
          fmt($f_prefix, $c_prefix), " ",
          fmt($f_msg, $c_msg);
}
