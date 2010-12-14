#!/usr/bin/env perl
# Hackage to convert OpenSSH/OpenSSL keys to lsh S-expressions.
# (Written since 'lsh' only comes with a public key conversion tool.)
#
# Usage (private key):
#
#     ./pkey-sexp.pl ~/.ssh/id_rsa -p "passphrase" \ 
#         | sexp-conv -s transport | lsh-writekey -o ~/.lsh/identity
#
#     * lsh-writekey will also output identity.pub to the same directory.
#
#     * Use 'lsh-writekey --label' as the equivalent to key comment.
#
# Usage (public key):
#
#     ./pkey-sexp.pl ~/.ssh/id_rsa.pub \
#         | sexp-conv -s transport > identity.pub
#
# Notes:
#
#     * lsh prefixes some bignums with a zero byte. I haven't figured out
#       why yet (signed-ness?), but it seems to require that zero byte
#       whenever it is present. So this script adds the prefix for /every/
#       bignum, which seems to work fine. This causes noticeable difference
#       when comparing sexps in their "advanced" (base64) encodings, but
#       this can be ignored.
#
#     * lsh-writekey requires input to be in 'transport' encoding.
#
#     * Converting s-exps to OpenSSL keys is not possible yet.
#
#     * The statement that 'lsh' does not come with a private key conversion
#       tool is only partially true: lsh's 'nettle' library does come with
#       pkcs1-conv, able to import RSA-PKCS#1 keys. Usage:
#         openssl rsa -in id_rsa | pkcs1-conv > identity
#           (outputs decrypted private key)
#         openssl rsa -in id_rsa | pkcs1-conv | lsh-writekey
#           (public and encrypted private)
#         ssh-keygen -f id_rsa -em PEM | pkcs1-conv > identity.pub
#           (public key)

use strict;
use Getopt::Long qw(:config bundling no_ignore_case);
use Crypt::Keys;
use Crypt::OpenSSL::Bignum;
use Math::Pari;
use Data::Dumper;

sub write_sexp {
	my ($sexp) = @_;
	if (ref $sexp eq 'ARRAY') {
		my $i = 0;
		print "(";
		for my $item (@$sexp) {
			$i++ and print " ";
			write_sexp($item);
		}
		print ")";
	}
	elsif (ref $sexp eq 'Math::Pari') {
		my $hex = lc Crypt::OpenSSL::Bignum->new_from_decimal($sexp)->to_hex;
		print "#00$hex#";
	}
	else {
		print $sexp;
	}
}

my ($file, $passphrase, $key, $f, %d, $sexp);

GetOptions(
	"p|passphrase=s" => \$passphrase,
) or die "error: usage";

$file = shift(@ARGV);
$key = Crypt::Keys->read(Filename => $file, Passphrase => $passphrase)
	or die "error: failed to load key: $file\n";

$f = $key->{Format};
%d = %{$key->{Data}};

if ($f =~ /^Private::RSA::/) {
	$sexp =
		["private-key",
			["rsa-pkcs1",
				[n => $d{n}],
				[e => PARI($d{e})],

				[d => $d{d}],
				[p => $d{p}],
				[q => $d{q}],

				[a => $d{dp}],
				[b => $d{dq}],
				[c => $d{iqmp}],
			],
		];
}
elsif ($f =~ /^Public::RSA::/) {
	$sexp =
		["public-key",
			["rsa-pkcs1-sha1",
				[n => $d{n}],
				[e => $d{e}],
			],
		];
}
elsif ($f =~ /^Private::DSA::/) {
	$sexp =
		["private-key",
			["dsa",
				[p => $d{p}],
				[q => $d{q}],
				[g => $d{g}],
				[y => $d{pub_key}],
				[x => $d{priv_key}],
			],
		];
}
elsif ($f =~ /^Public::DSA::/) {
	$sexp =
		["public-key",
			["dsa",
				[p => $d{p}],
				[q => $d{q}],
				[g => $d{g}],
				[y => $d{pub_key}],
			],
		];
}
else {
	print Dumper($key)."\n";
	die "error: unsupported key type $f\n";
}
write_sexp($sexp);
print "\n";
