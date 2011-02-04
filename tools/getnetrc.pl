#!/usr/bin/env perl
# getnetrc v1.2
# Grabs login data from ~/.netrc
#
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
'Usage: getnetrc [-dnu] [-f format] machine [login]

  -d  ignore the default entry
  -n  do not print final newline
  -f  format the output as specified (default is %l:%p)
  -u  URL-encode each item separately

Format strings:
  %m, %h       machine (hostname)
  %l, %u       login (username)
  %p           password
  %a           account
  %%, %n, %0   percent sign, newline, null byte

See manpage of ftp(1) for description of .netrc
The .netrc file format is described in the manual page of ftp(1).
';
	return 0;
}

# parse format string
sub fmt) {
	my ($str, %data) = @_;
	$data{"%"} = "%";
	$str =~ s/(%(.))/exists $data{$2}?(defined $data{$2}?$data{$2}:""):$1/ge;
	return $str;
}

sub uri_encode {
	$str = shift;
	$str =~ s/([^A-Za-z0-9.!~*'()-])/sprintf("%%%02X", ord($1))/seg;
	return $str;
}

### Command line options
my $format = "%l:%p";
my $format_nonewline = 0;
my $format_url_encode = 0;
my $no_default = 0;
GetOptions(
	"f=s" => \$format,
	"n" => \$format_nonewline,
	"u" => \$format_url_encode,
	"d" => \$no_default,
	"help" => sub { exit msg_help },
) or exit msg_usage;

my $machine = shift @ARGV;
my $login = shift @ARGV;
exit msg_usage if !defined $machine;

### Look up netrc entry
my $entry = Net::Netrc->lookup($machine, $login);

exit 1 if (!defined $entry) or (!defined $entry->{machine} and $no_default);

### Display results
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

if (!$format_nonewline) {
	$format .= '%n';
}

print fmt($format, %output);
