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

key_types="RSA, ECP256, ECP384, ECP521, Ed25519, Ed448"

usage() {
	echo "Usage: $progname [options]"
	echo
	echo_opt "-b BITS" "generated private key size in bits (RSA only)"
	echo_opt "-c CRTFILE" "output certificate"
	echo_opt "-k KEYFILE" "output generated private key"
	echo_opt "-K KEYFILE" "input existing private key"
	echo_opt "-s SUBJECT" "certificate subject"
	echo_opt "-t TYPE" "generated private key type ($key_types)"
	echo_opt "-y YEARS" "certificate validity in years"
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
opt_keybits=""
opt_keyin=""
opt_keyout=""
opt_keytype=""
opt_subject=""
maxyears=50

while getopts ":b:c:fK:k:s:t:y:" OPT; do
	case $OPT in
	b) opt_keybits=$OPTARG;;
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

(( ! $# ))         || err "unrecognized arguments ${*@Q}"
[[ $opt_subject ]] || err "certificate subject (-s) not specified"
[[ $opt_certout ]] || err "output certificate (-c) not specified"

if [[ $opt_keyin && $opt_keyout ]]; then
	err "both input private key (-K) and output key (-k) cannot be specified"
elif [[ $opt_keyin ]]; then
	if [[ $opt_keytype ]]; then
		err "both input private key (-K) and key type (-t) cannot be specified"
	fi
	if [[ $opt_keybits ]]; then
		err "both input private key (-K) and key bits (-b) cannot be specified"
	fi
elif [[ $opt_keyout ]]; then
	: "${opt_keytype:=rsa}"
	if [[ $opt_keytype == rsa ]]; then
		: "${opt_keybits:=4096}"
		if [[ $opt_keybits != @(2048|4096) ]]; then
			err "unsupported RSA key size $opt_keybits"
		fi
	elif [[ $opt_keytype == @(rsa2048|rsa4096) ]]; then
		if [[ $opt_keybits && $opt_keybits != ${opt_keytype#rsa} ]]; then
			err "mismatching RSA key sizes given; key bits (-b) should not be specified"
		fi
		opt_keybits=${opt_keytype#rsa}
		opt_keytype=rsa
	elif [[ $opt_keytype == @(ecp256|ecp384|ecp521|ed25519|ed448) ]]; then
		if [[ $opt_keybits ]]; then
			err "${opt_keytype^^} keys are of fixed size; key bits (-b) should not be specified"
		fi
	else
		err "unsupported key type '$opt_keytype' (must be one of: $key_types)"
	fi
else
	err "neither input private key (-K) nor output private key (-k) specified"
fi

((!errors)) || exit

if (( opt_certyears < 1 )); then
	die "expiry time (-y) must be at least 1 year"
elif (( opt_certyears > 50 )); then
	die "expiry time (-y) of $opt_certyears years is too large"
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
	info "generating ${opt_keytype^^}${opt_keybits:+-}${opt_keybits} private key '$opt_keyout'"
	if [[ $tool == openssl ]]; then
		args=()
		case $opt_keytype in
			rsa)
				args=(-algorithm RSA -pkeyopt rsa_keygen_bits:"$opt_keybits");;
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
			rsa)
				args=(--key-type=rsa --bits="$opt_keybits");;
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
	info "using existing private key '$opt_keyin'"
fi

# create certificate

info "creating root certificate '$opt_certout'"
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

info "certificate created"
