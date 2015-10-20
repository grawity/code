#!/usr/bin/env perl
# pcip - 'ip' wrapper translating PCI & MAC addresses to interface names
# Originally written for http://superuser.com/questions/978088/
# (c) 2015 Mantas Mikulėnas <grawity@gmail.com>
# Released under the MIT Expat License
#
# Match by PCI device:
#
#     pcip link set pci:03:00.0 up
#
# Match by MAC address:
#
#     pcip addr add 10.0.42.1/16 dev mac:48:5d:04:85:fc:d7
#
# Use with other commands besides `ip`:
#
#     pcip -c ifconfig mac:485d.0485.fcd7 up

use v5.10;
use warnings;
use strict;
use File::Basename;
use Getopt::Long qw(:config no_ignore_case bundling);
use List::Util qw(max);

sub _warn { warn "$0: $_[0]\n"; return; }

sub read_line {
    my ($path) = @_;

    if (open(my $fh, "<", $path)) {
        chomp(my $line = <$fh>);
        close($fh);
        return $line;
    } else {
        _warn("could not open '$path': $!");
    }
}

sub canonicalize_mac {
    my ($addr) = @_;

    my $vbyte = qr/[0-9a-f]{1,2}/;
    my $fbyte = qr/[0-9a-f]{2}/;
    my @match;

    # convert Windows-style addresses with dashes
    $addr = lc($addr);
    $addr =~ y/-/:/;
    # expand missing leading 0's, parse Cisco-style addresses
    if (@match = $addr =~ /^($vbyte):($vbyte):($vbyte):($vbyte):($vbyte):($vbyte)$/ or
        @match = $addr =~ /^($fbyte)($fbyte)\.($fbyte)($fbyte)\.($fbyte)($fbyte)$/ or
        @match = $addr =~ /^($fbyte)($fbyte)($fbyte)($fbyte)($fbyte)($fbyte)$/)
    {
        return join(":", map {sprintf("%02x", hex $_)} @match);
    }
    return $addr;
}

sub ifname_from_pci {
    my ($pciid) = @_;

    unless ($pciid =~ /^[0-9a-f]{4}:/) {
        $pciid = "0000:$pciid";
    }
    return map {basename($_)}
           glob("/sys/bus/pci/devices/$pciid/net/*/");
}

sub ifname_from_mac {
    my ($arg) = @_;

    my $addr = canonicalize_mac($arg);
    if (!$addr) {
        _warn("invalid MAC address '$arg'");
    } else {
        return map {basename($_)}
               grep {read_line("$_/address") eq $addr}
               grep {-f "$_/address"}
               glob("/sys/class/net/*/");
    }
}

sub expand {
    my ($arg) = @_;

    for ($arg) {
        if (/^pci:(.+)/) {
            return ifname_from_pci($1);
        }
        elsif (/^mac:(.+)/) {
            return ifname_from_mac($1);
        }
        else {
            _warn("unknown expansion '$arg'");
        }
    }
}

sub replace_first {
    my ($func, $start, @args) = @_;

    my $pos = -1;
    my $arg = undef;
    for my $i ($start..$#args) {
        if ($args[$i] =~ /^(pci|mac):/) {
            $pos = $i;
            $arg = $args[$i];
            last;
        }
    }
    if ($pos == -1) {
        return $func->(@args);
    } else {
        my @names = expand($arg);
        if (!@names) {
            _warn("could not translate '$arg' to an interface name");
        } else {
            return map {
                $args[$pos] = $_;
                replace_first($func, $pos+1, @args)
            } @names;
        }
    }
}


my $cmd = "ip";
my $fail = 0;

my $handler = sub {
    my (@args) = @_;

    my $ret = (system {$args[0]} @args) >> 8;
    if ($ret) {
        _warn("call {@args} failed with code $ret");
    }
    if ($fail) {
        exit $ret;
    }
    return $ret;
};

GetOptions(
    "c|command=s" => \$cmd,
    "f|fail!" => \$fail,
);

my @cmd = ($cmd, @ARGV);
my @ret = replace_first($handler, 0, @cmd);

if (@ret) {
    exit max(@ret);
} else {
    _warn("no commands were run");
    exit 1;
}
# vim: ts=4:sw=4:et
