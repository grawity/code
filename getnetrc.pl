#!/usr/bin/perl
# getnetrc v1.2
# A simple tool for grabbing login data from ~/.netrc
#
# (c) 2009 Mantas Mikulėnas <grawity@gmail.com>
# Released under WTFPL v2 <http://sam.zoy.org/wtfpl/>

use warnings;
use strict;

use Getopt::Long qw(:config gnu_getopt no_ignore_case);
use Net::Netrc;

sub msg_usage {
	print STDERR "Usage: getnetrc [-du] [-f format] machine [login]\n";
	return 2;
}
sub msg_help {
	print
'Usage: getnetrc [-du] [-f format] machine [login]

  -d  ignore the default entry (which is useless for anything but ftp)
  -f  format the output as specified (default is %u:%p)
  -u  URL-encode each item separately

These format strings are understood:
  %l, %u       login (username)
  %p           password
  %a           account name (mostly useless)
  %m, %h       machine name (hostname)
  %%, %n, %0   percent sign, newline, null byte
Everything else is taken literally.

The .netrc file format is described in the manual page of ftp(1).
';
	return 0;
}

# parse format string
sub fmt($%) {
	my ($str, %data) = @_;
	$data{"%"} = "%";
	$str =~ s/(%(.))/exists $data{$2}?(defined $data{$2}?$data{$2}:""):$1/ge;
	return $str;
}

# URL-encode data
sub url_encode($) {
	$_ = shift;
	s/([^A-Za-z0-9.!~*'()-])/sprintf("%%%02X", ord($1))/seg;
	return $_;
}

# parse @ARGV
my $format = "%u:%p";
my $format_url_encode = 0;
my $no_default = 0;
GetOptions(
	"f=s" => \$format,
	"u" => \$format_url_encode,
	"d" => \$no_default,
	"help" => sub { exit msg_help },
) or exit msg_usage;

my $machine = shift @ARGV;
my $login = shift @ARGV;
exit msg_usage if !defined $machine;

# do the lookup and print results
my $entry = Net::Netrc->lookup($machine, $login);

# lookup failed
exit 1 if (!defined $entry) or (!defined $entry->{machine} and $no_default);

my %output = (
	a => $entry->{account},
	h => $entry->{machine},
	l => $entry->{login},
	m => $entry->{machine},
	p => $entry->{password},
	u => $entry->{login},
);
if ($format_url_encode) {
	map { $output{$_} = url_encode($output{$_}) } keys %output;
}
@output{"n", "0"} = ("\n", "\0");

print fmt($format, %output), "\n";
