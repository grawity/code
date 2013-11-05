#!/bin/sh

nickname="Your Nickname Goes Here"

rsabits=2432 # GnuTLS default

have() { command -v "$1" > /dev/null 2>&1; }

if have openssl; then
	# OpenSSL

	openssl req -new -subj "/CN=${nickname//\//\\/}" -days 3650 \
		-extensions v3_req -x509 -out freenode.cert \
		-newkey rsa:"$rsabits" -nodes -keyout freenode.pkey

	# note: OpenSSL by default writes private keys in PKCS#8 format, and
	# some other libraries do not line that; therefore, convert it to a
	# bare RSA key:

	openssl rsa -in freenode.pkey -out freenode.key
	rm -f freenode.pkey

	echo "Your certificate and private key are in 'freenode.cert' and 'freenode.key'"

	fpr=$(openssl x509 -in freenode.cert -noout -sha1 -fingerprint \
		| sed 's/.*=//; s/://g; y/ABCDEF/abcdef/')

	echo "The fingerprint is $fpr"

elif have certtool; then
	 # GnuTLS

	(echo "cn = \"${nickname//\"/\\\"}\""
	 echo "expiration_days = 3650"
	 echo "tls_www_client") > freenode.tmpl

	certtool --generate-privkey --bits="$rsabits" --outfile=freenode.key

	certtool --generate-self-signed --load-privkey=freenode.key \
		--template=freenode.tmpl --outfile=freenode.cert

	rm -f freenode.tmpl

	echo "Your certificate and private key are in 'freenode.cert' and 'freenode.key'"

	fpr=$(certtool --certificate-info < freenode.cert \
		| sed -n '/SHA-1 fingerprint/ { n; s/^\t*//; p; q }')

	echo "The fingerprint is $fpr"

elif have hxtool; then
	# Heimdal
	
	hxtool cert-sign --subject="CN=${nickname//,/_}" --type="https-client" \
		--self-signed --certificate="FILE:freenode.cert+key" \
		--generate-key=rsa --key-bits="$rsabits"
	
	echo "Your certificate and private key are in 'freenode.cert+key'"

else
	echo "I give up. You lack the necessary tools." >&2
	false
fi
