#!/usr/bin/perl -w
# getnetrc v1.2
# Grabs login data from ~/.netrc
#
# Released under WTFPL v2 <http://sam.zoy.org/wtfpl/>
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

  -d  ignore the default entry
  -f  format the output as specified (default is %l:%p)
  -u  URL-encode each item separately

These format strings are understood:
  %m, %h       machine (hostname)
  %l, %u       login (username)
  %p           password
  %a           account
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

sub uri_encode($) {
	$_ = shift;
	s/([^A-Za-z0-9.!~*'()-])/sprintf("%%%02X", ord($1))/seg;
	return $_;
}

my $format = "%l:%p";
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

my $entry = Net::Netrc->lookup($machine, $login);

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
	$output{$_} = uri_encode($output{$_}) for keys %output;
}
@output{"n", "0"} = ("\n", "\0");

print fmt($format, %output), "\n";
