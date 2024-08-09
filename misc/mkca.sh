#!/usr/bin/env bash
# make-root -- create a self-signed X.509v3 root CA certificate
# (c) 2019 Mantas Mikulėnas <grawity@gmail.com>
# SPDX-License-Identifier: MIT <https://spdx.org/licenses/MIT.html>
#
# Certificate profile:
#  * Basic constraints: <critical>, CA=TRUE, no path length
#        OID 2.5.29.19, BOOL true, OCTET { SEQ [ BOOL true ] }
#  * Key usage: <critical>, digital signature, cert sign, CRL sign (0x01 | 0x20 | 0x40)
#        OID 2.5.29.15, BOOL true, OCTET { BITSTRING <pad 1> '1100001'b }
#  * Subject key identifier: [hash]
#        OID 2.5.29.14, OCTET { OCTET[20] }

. lib.bash || exit

key_types="rsa2048 rsa4096 ecp256 ecp384 ecp521 ed25519 ed448"
default_key_type="ecp256"

usage() {
	echo "Usage: $progname [options]"
	echo
	echo_opt "-c CRTFILE" "output certificate"
	echo_opt "-k KEYFILE" "output generated private key"
	echo_opt "-K KEYFILE" "input existing private key"
	echo_opt "-s SUBJECT" "certificate subject"
	echo_opt "-t TYPE" "generated private key type ($key_types)"
	echo_opt "-y YEARS" "certificate validity in years"
	echo_opt "-f" "force overwriting existing files"
}

dn_reverse() {
	local in="$1" insep="$2" outsep="$3" out="" tmp=""
	in=$insep${in#$insep}
	while [[ $in == "$insep"* ]]; do
		tmp=${in##*$insep}
		tmp=${tmp# }
		out+=$outsep$tmp
		in=${in%$insep*}
	done
	if [[ $outsep == , ]]; then
		out=${out#$outsep}
	fi
	echo "$out"
}

opt_certout=""
opt_certyears=25
opt_clobber=0
opt_keyin=""
opt_keyout=""
opt_keytype=""
opt_subject=""
maxyears=50

while getopts ":GOc:fK:k:s:t:y:" OPT; do
	case $OPT in
	G) tool=gnutls;;
	O) tool=openssl;;
	c) opt_certout=$OPTARG;;
	f) opt_clobber=1;;
	K) opt_keyin=$OPTARG;;
	k) opt_keyout=$OPTARG;;
	s) opt_subject=$OPTARG;;
	t) opt_keytype=${OPTARG,,};;
	y) opt_certyears=$OPTARG;;
	*) lib:die_getopts;;
	esac
done; shift $((OPTIND-1))

if (( $# )); then
	vdie "unrecognized arguments: ${*@Q}"
elif [[ ! $opt_subject ]]; then
	vdie "subject (-s) not specified"
elif [[ ! $opt_certout ]]; then
	vdie "certificate output file (-c) not specified"
elif [[ $opt_keyin && $opt_keyout ]]; then
	vdie "conflicting options (-K and -k) specified"
elif [[ $opt_keyin && $opt_keytype ]]; then
	vdie "conflicting options (-K and -t) specified"
elif [[ ! $opt_keyin && ! $opt_keyout ]]; then
	vdie "private key location (-K or -k) not specified"
elif [[ $opt_certout == @(-|/dev/*) ]]; then
	vdie "writing certificate to stdout or device not supported"
elif [[ $opt_keyout == @(-|/dev/*) ]]; then
	vdie "writing private key to stdout or device not supported"
elif (( opt_certyears < 1 )); then
	vdie "expiry time (-y) must be at least 1y"
elif (( opt_certyears > 50 )); then
	vdie "expiry time (-y) of $opt_certyears years is too large"
elif (( opt_certyears > 25 )); then
	warn "expiry time (-y) of $opt_certyears years is very large"
	confirm "continue?" || exit
fi

if echo "$opt_subject" | LC_ALL=C grep -Pqs '[\x80-\xFF]'; then
	warn "UTF-8 in CA certificate subjects is not recommended"
	confirm "continue?" || exit
fi

if [[ $opt_keyin && ! -f $opt_keyin ]]; then
	die "private key file '$opt_keyin' does not exist"
elif [[ $opt_certout && -f $opt_certout ]] && (( !opt_clobber )); then
	warn "certificate '$opt_certout' already exists"
	confirm "overwrite file?" || exit
elif [[ $opt_keyout && -f $opt_keyout ]] && (( !opt_clobber )); then
	warn "private key file '$opt_keyout' already exists"
	confirm "overwrite file?" || exit
fi

if [[ ! $tool ]]; then
	if have openssl; then
		tool=openssl
	elif have certtool; then
		tool=gnutls
	fi
fi

# create private key

if [[ $opt_keyout ]]; then
	vmsg "generating ${opt_keytype^^} private key '$opt_keyout'"
	if [[ $tool == openssl ]]; then
		args=()
		case $opt_keytype in
			rsa2048|rsa4096)
				args=(-algorithm RSA -pkeyopt rsa_keygen_bits:"${opt_keytype#rsa}");;
			ecp256|ecp384|ecp521)
				args=(-algorithm EC -pkeyopt ec_paramgen_curve:"P-${opt_keytype#ecp}");;
			ed25519|ed448)
				args=(-algorithm ${opt_keytype^^});;
			*)
				die "unsupported key type '$opt_keytype' (using OpenSSL genpkey)"
		esac
		(umask 077; openssl genpkey "${args[@]}" -out "$opt_keyout")
	elif [[ $tool == gnutls ]]; then
		args=()
		case $opt_keytype in
			rsa2048|rsa4096)
				args=(--key-type=rsa --bits="${opt_keytype#rsa}");;
			ecp256|ecp384|ecp521)
				args=(--key-type=ecdsa --curve="SECP${opt_keytype#ecp}R1");;
			ed25519)
				args=(--key-type=ed25519);;
			*)
				die "unsupported key type '$opt_keytype' (using GnuTLS certtool)"
		esac
		args+=(--pkcs8 --password="")
		(umask 077; certtool --generate-privkey "${args[@]}" --outfile="$opt_keyout")
	else
		die "no key generation tools available"
	fi
	opt_keyin=$opt_keyout
else
	vmsg "using existing private key '$opt_keyin'"
fi

# create certificate

vmsg "creating root certificate '$opt_certout'"
days=$(( opt_certyears * 36525 / 100 ))
debug "subject: $opt_subject"
debug "expiry: $days days"
if [[ $tool == openssl ]]; then
	if [[ $opt_subject != *=* ]]; then
		opt_subject="/CN=$opt_subject"
	fi
	if [[ $opt_subject != /* ]]; then
		warn "subject is not in OpenSSL format (must be /C=XX/O=Bar/CN=Foo)"
		opt_subject=$(dn_reverse "$opt_subject" "," "/")
		warn "rewritten subject to '$opt_subject'"
	fi
	if [[ $opt_subject == /CN=*/* ]]; then
		warn "subject order seems reversed (OpenSSL wants CN-last)"
		opt_subject=$(dn_reverse "$opt_subject" "/" "/")
		warn "rewritten subject to '$opt_subject'"
	fi
	cnf=$(mktemp /tmp/openssl.XXXXXXXXXX)
	cat > "$cnf" <<-EOF
	[req]
	# (1.1.1a) Without 'utf8=yes', trying to include non-ASCII text results in a malformed UTF8String
	utf8 = yes
	distinguished_name = dn
	x509_extensions = exts
	[dn]
	[exts]
	basicConstraints = critical, CA:TRUE
	keyUsage = critical, digitalSignature, cRLSign, keyCertSign
	subjectKeyIdentifier = hash
	EOF
	# openssl automatically generates a 160-bit serial number
	openssl req -new -x509 -config "$cnf" -subj "$opt_subject" -days "$days" -key "$opt_keyin" -out "$opt_certout"
	r=$?
	rm -f "$cnf"
	if (( r )); then
		rm -f "$opt_certout"
		die "certificate creation failed"
	fi
	openssl x509 -in "$opt_certout" -noout -text -certopt no_sigdump -nameopt RFC2253 -nameopt sep_comma_plus_space
elif [[ $tool == gnutls ]]; then
	if [[ $(certtool --version) == certtool\ 3.6.* ]]; then
		die "GnuTLS certtool (3.6.6) includes spurious zero bits in keyUsage bitstring"
	fi
	if [[ $opt_subject != *=* ]]; then
		opt_subject="CN=$opt_subject"
	fi
	if [[ $opt_subject == /* ]]; then
		warn "subject is not in RFC 2253 format (must be CN=Foo,O=Bar,C=XX)"
		opt_subject=$(dn_reverse "$opt_subject" "/" ",")
		warn "rewritten subject to '$opt_subject'"
	fi
	if [[ $opt_subject == *,CN=* ]]; then
		warn "subject order seems reversed (RFC 2253 wants CN-first)"
		opt_subject=$(dn_reverse "$opt_subject" "," ",")
		warn "rewritten subject to '$opt_subject'"
	fi
	cnf=$(mktemp /tmp/certtool.XXXXXXXXXX)
	cat > "$cnf" <<-EOF
	dn = "$opt_subject"
	expiration_days = $days
	ca
	signing_key
	cert_signing_key
	crl_signing_key
	EOF
	# certtool automatically generates a 160-bit serial number
	certtool --generate-self-signed --load-privkey="$opt_keyin" --template="$cnf" --outfile="$opt_certout"; r=$?
	rm -f "$cnf"
	if (( r )); then
		rm -f "$opt_certout"
		die "certificate creation failed"
	fi
	# certtool automatically shows the final certificate
else
	die "no certificate building tools available"
fi
