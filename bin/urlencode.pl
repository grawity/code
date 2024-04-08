#!/usr/bin/env perl
# vim: ts=4:sw=4:noet
use utf8;
use warnings;
use strict;
use Getopt::Long qw(:config bundling no_ignore_case);

my %opts;

sub usage {
	print STDERR for (
		"Usage: urlencode [options] [string]\n",
		"\n",
		"The default format is hexadecimal percent-encoding as in URLs.\n",
		"\n",
		#----||||----||||----||||----||||
		"Modes:\n",
		"    -d, --decode            decode\n",
		"    -q, --qp, --quoted-printable\n",
		"                            encode/decode Quoted-Printable\n",
		"    -X, --xml               encode/decode XML entities\n",
		"\n",
		"Encode tweaks (for default mode):\n",
		"        --ldap-dn           encode LDAP DN (allowing '=')\n",
		"        --mq                encode for mq (':'-prefix)\n",
		"    -o, --octal             use C octal escapes (\\123)\n",
		"    -p, --path              encode full path (allowing '/')\n",
		"    -x, --hex               use C hex escapes (\\xAB)\n",
		"    -P, --parens            do not encode parentheses\n",
		"\n",
		"Misc options (default mode only):\n",
		"    -D, --decode-plus       decode + as space (URL mode only)\n",
		"    -n, --no-newline        do not print trailing newline\n",
		"    -S, --safe-filename     substitute unsafe filename characters\n",
		#----||||----||||----||||----||||
	);
	exit;
}

my %entities = qw(
	amp		&
	gt		>
	lt		<
	quot	"
	scaron	š
);

sub decode {
	my ($buf) = @_;

	for ($buf) {
		if ($opts{format_QP}) {
			s/=\n//gs;
			s/=([A-F0-9]{2})/pack('C', hex($1))/gse;
		} elsif ($opts{format_ldap_dn}) {
			s/\\([0-9A-F]{2})/pack('C', hex($1))/gse;
		} elsif ($opts{format_locale}) {
			s/<U([0-9A-F]{4,8})>/pack('C', hex($1))/gse;
		} elsif ($opts{format_xml}) {
			utf8::decode($_);
			s{&(\w+|#\d+);}{
				my $name = $1;
				($name =~ s/^#//)
					? chr(int($name))
					: $entities{$name}
			}gse;
			utf8::encode($_);
		} else {
			if ($opts{format_mq}) {
				s/^://;
			}
			s/%([A-Fa-f0-9]{2})/pack('C', hex($1))/gse;
			if ($opts{decode_plus}) {
				s/\+/ /g;
			}
			if ($opts{safe_filename}) {
				s!/!⁄!g;
				s!<!‹!g;
				s!>!›!g;
				s!"!'!g;
				s![:?*\\]!_!g;
			}
		}
	}

	return $buf;
}

sub encode {
	my ($buf) = @_;

	for ($buf) {
		if ($opts{format_mq}) {
			s/[\x00-\x1F %]/sprintf("%%%02X", ord($&))/gse;
			s/^$|^:/:$&/;
		} elsif ($opts{format_QP}) {
			s/[^\x20-\x3C\x3E-\x7E]/sprintf("=%02X", ord($&))/gse;
			#s/.{72}/$&=\n/g;
		} elsif ($opts{format_c_hex}) {
			s/[^A-Za-z0-9_. \/-]/sprintf("\\x%02X", ord($&))/gse;
		} elsif ($opts{format_c_octal}) {
			s/[^A-Za-z0-9_. \/-]/sprintf("\\%03o", ord($&))/gse;
		} elsif ($opts{format_xml}) {
			s/&/&amp;/g;
			s/</&lt;/g;
			s/>/&gt;/g;
			s/"/&quot;/g;
		} else {
			s/[^\/A-Za-z0-9_.!~*,=():-]/sprintf("%%%02X", ord($&))/gse;
			if (!$opts{format_ldap_dn}) {
				s/[,=]/sprintf("%%%02X", ord($&))/gse;
			}
			if (!$opts{format_url_with_slashes}) {
				s/\//sprintf("%%%02X", ord($&))/gse;
			}
			if (!$opts{format_url_with_parens}) {
				s/[()]/sprintf("%%%02X", ord($&))/gse;
			}
		}
	}

	return $buf;
}

sub process {
	my ($buf) = @_;

	if ($opts{decode}) {
		print decode($buf);
	} else {
		print encode($buf);
	}

	print "\n" unless $opts{no_newline};
}

my @args;

GetOptions(
	"a|arg=s" => \@args,
	"d|decode" => \$opts{decode},
	"D|decode-plus" => \$opts{decode_plus},
	"o|octal" => \$opts{format_c_octal},
	"p|path" => \$opts{format_url_with_slashes},
	"P|parens" => \$opts{format_url_with_parens},
	"q|qp|quoted-printable" => \$opts{format_QP},
	"libc" => \$opts{format_locale},
	"ldap-dn" => \$opts{format_ldap_dn},
	"mq" => \$opts{format_mq},
	"n|no-newline" => \$opts{no_newline},
	"r|raw!" => \$opts{no_newline},
	"S|safe-filename" => \$opts{safe_filename},
	"x|hex" => \$opts{format_c_hex},
	"X|xml" => \$opts{format_xml},
) || usage();

$opts{decode} ||= $opts{decode_plus};

if (@args || @ARGV) {
	process($_) for (@args, @ARGV);
} else {
	if ($opts{decode} && $opts{format_QP}) {
		my $buf = do { $/ = undef; <STDIN> };
		print decode($buf);
	} else {
		while (<STDIN>) {
			chomp($_) unless $opts{no_newline};
			process($_);
		}
	}
}
