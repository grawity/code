#!/bin/sh

nickname="$1"
network="freenode"

rsabits=2048 # GnuTLS default

have() { command -v "$1" > /dev/null 2>&1; }

if have openssl; then
	# OpenSSL

	openssl req -new -subj "/CN=${nickname//\//\\/}" -days 3650 \
		-extensions v3_req -x509 -out "$network.cert" \
		-newkey "rsa:$rsabits" -nodes -keyout "$network.pkey"

	# convert PKCS#8 to bare OpenSSL (PKCS#1?) format
	openssl rsa -in "$network.pkey" -out "$network.key"
	rm -f "$network.pkey"

	echo "Your certificate and private key are in '$network.cert' and '$network.key'"

	fpr=$(openssl x509 -in "$network.cert" -noout -sha1 -fingerprint \
		| sed 's/.*=//; s/://g; y/ABCDEF/abcdef/')

	echo "The fingerprint is $fpr"

elif have certtool; then
	 # GnuTLS

	(echo "cn = \"${nickname//\"/\\\"}\""
	 echo "expiration_days = 3650"
	 echo "tls_www_client") > $network.tmpl

	certtool --generate-privkey --bits="$rsabits" --outfile="$network.key"
	certtool --generate-self-signed --load-privkey="$network.key" \
		--template="$network.tmpl" --outfile="$network.cert"
	rm -f "$network.tmpl"

	echo "Your certificate and private key are in '$network.cert' and '$network.key'"

	fpr=$(certtool --certificate-info < "$network.cert" \
		| sed -n '/SHA-1 fingerprint/ { n; s/^\t*//; p; q }')

	echo "The fingerprint is $fpr"

elif have hxtool; then
	# Heimdal
	
	hxtool cert-sign --subject="CN=${nickname//,/_}" --type="https-client" \
		--self-signed --certificate="FILE:$network.bundle" \
		--generate-key=rsa --key-bits="$rsabits"
	
	sed -n '/CERTIFICATE/,/CERTIFICATE/p' < "$network.bundle" > "$network.cert"
	sed -n '/PRIVATE KEY/,/PRIVATE KEY/p' < "$network.bundle" > "$network.key"
	rm -f "$network.bundle"

	echo "Your certificate and private key are in '$network.cert' and '$network.key'"

	if have sha1sum && have base64; then
		fpr=$(cat "$network.cert" \
			| sed '/^-//d' \
			| base64 -d \
			| sha1sum \
			| sed 's/ .*//')

		echo "The fingerprint is $fpr"
	fi

else
	echo "I give up. You lack the necessary tools." >&2
	false
fi
