#!/bin/bash
SOURCE_URL="http://purl.oclc.org/NET/grawity/authorized_keys.txt"
SELF_URL="http://purl.oclc.org/NET/grawity/code/update-sshauth.sh.gpg"
SIGNER_KEY="D24F6CB2C1B52632"
KEYSERVERS=( keyserver.noreply.org pool.sks-keyservers.net keyserver.ubuntu.com )

umask 077

mkdir -p ~/.ssh/

# check if application is in $PATH
have() { which "$1" &> /dev/null; }

# used when I cannot figure out how to deal with argv in one-liners
shellquote() {
	echo \'${1//\'/\'\\\'\'}\' #'# vim syntax hilighting
}

# download a file over HTTP 
http_fetch() {
	UA="update-sshauth on $( id -un )@$( hostname )"
	URL="$1"
	OUT="$2"
	if have curl; then
		curl -A "$UA" -LSs "$URL" --output "$OUT"
	elif have wget; then
		wget -U "$UA" -q "$URL" -O "$OUT"
	elif have lynx; then
		lynx --useragent="$UA" -source "$URL" > "$OUT"
	elif have w3m; then
		w3m -dump_source "$URL" > "$OUT"
	elif have links; then
		links -source "$URL" > "$OUT"
	elif have elinks; then
		elinks -source "$URL" > "$OUT"
	elif have perl; then
		perl -MLWP::Simple -e 'getprint $ARGV[0]' "$URL" > "$OUT"
	elif have python; then
		python -c 'import sys, urllib2; sys.stdout.write(urllib2.urlopen(sys.argv[1])).read())' "$URL" > "$OUT"
	elif have php && php -i | grep -qsi "^allow_url_fopen => on"; then
		php -r 'echo file_get_contents(urlencode($argv[1])), FILE_BINARY);' "$URL" > "$OUT"
	elif have php && php -i | grep -qs "^curl$"; then
		php -r '$ch = curl_init($argv[1]); curl_setopt($ch, CURLOPT_FOLLOWLOCATION, 1); curl_exec($ch);' "$URL" > "$OUT"
	elif have tclsh; then
		tclsh - <<< 'package require http; fconfigure stdout -translation binary; puts -nonewline [http::data [http::geturl [lindex $argv 1]]]' "$URL" > "$OUT"
	else
		# Damn.
		echo "update-sshauth: no download tool available" >&2
		exit 3
	fi
}

# download a GPG public key
gpg_recv_key() {
	local keyid="$1"
	local server="$2"

	local gpg_out="$( gpg --status-fd=3 3>&1 2>/dev/null >&1 --keyserver "$server" --recv-key "$keyid" )"

	if ! grep -qs "^\[GNUPG:\] IMPORT_OK " <<< "$gpg_out"; then
		echo "[update-sshauth] key update failed from $server"
		echo "$gpg_out"
		echo "(end of gpg output)"
		return 1
	fi
	return 0
}

# update signer's GPG pubkey, retrying several keyservers
update_signer_key() {
	[ "$VERBOSE" == 1 ] && echo "Updating signer key $SIGNER_KEY"

	keyrecv_out="$( mktemp -t "gnupg.XXXXXXXXXX" )"
	for server in "${KEYSERVERS[@]}"; do
		[ "$VERBOSE" == 1 ] && echo "* trying $server"
		if gpg_recv_key "$SIGNER_KEY" "$server" >> "$keyrecv_out"
			then rm -f "$keyrecv_out"; return 0
			else sleep 3
		fi
	done
	return 1
}

rrfetch() {
	local url="$1"
	local output="$2"

	local max_retries=5
	local retry_wait=2

	local attempt=0
	while [ $(( attempt++ )) -lt $max_retries ]; do
		[ "$VERBOSE" == 1 ] && echo "Fetching $url (attempt $attempt)"

		http_fetch "$url" "$output"

		if [ -s "$output" ]; then
			# exists and not empty
			return 0
		else
			# retry
			rm -f "$output"
			sleep $retry_wait
		fi
	done
	rm -f "$output"
	return 1
}

verify_sig() {
	local file="$1"
	local gpg_out="$( gpg --quiet --status-fd=3 3>&1 2>/dev/null >&2 --verify "$file" )"
	[ "$VERBOSE" == 1 ] && echo "$gpg_out"

	if grep -qs "^\\[GNUPG:\\] NODATA " <<< "$gpg_out"
	then
		{	echo "update-sshauth: verification failed, file is empty"
			echo "file: $file"
			echo "$gpg_out"
			echo "(end of gpg output)"
		} >&2
		return 1

	# cryptographically valid signature
	elif grep -qs "^\\[GNUPG:\\] BADSIG " <<< "$gpg_out" ||
		! grep -qs "^\\[GNUPG:\\] GOODSIG " <<< "$gpg_out"
	then
		{	echo "update-sshauth: verification failed, invalid signature"
			echo "file: $file"
			echo "$gpg_out"
			echo "(end of gpg output)"
		} >&2
		return 1
	
	# valid signature from configured key
	elif ! grep -qs "^\\[GNUPG:\\] GOODSIG $SIGNER_KEY " <<< "$gpg_out"
	then
		{	echo "update-sshauth: verification failed, signed with unknown key"
			echo "file: $file"
			echo "$gpg_out"
			echo "(end of gpg output)"
		} >&2
		return 1
	
	# signature from ultimately trusted key (my own)
	elif ! grep -qs "^\\[GNUPG:\\] TRUST_ULTIMATE\$" <<< "$gpg_out"
	then
		{	echo "update-sshauth: verification failed, signer key not ultimately trusted"
			echo "file: $file"
			echo "$gpg_out"
			echo "(end of gpg output)"
		} >&2
		return 2
	
	# miscellaneous failures
	elif grep -qs "^\\[GNUPG:\\] ERROR " <<< "$gpg_out"
	then
		{	echo "update-sshauth: verification failed, reason unknown"
			echo "file: $file"
			echo "$gpg_out"
			echo "(end of gpg output)"
		} >&2
		return 1
	
	# all checks passed
	else
		return 0
	fi
}

## Parse command-line options.
ARGV="${@}"
VERBOSE=0
SELFUPDATE=1
while [ -n "$1" ]; do case "$1" in
-v|--verbose)
	VERBOSE=1
	;;
-r|--recv-key)
	update_signer_key && gpg --edit-key "$SIGNER_KEY" trust quit
	exit
	;;
-U)
	SELFUPDATE=0
	;;
*)
	echo "Unknown option $1"
	exit 1
	;;
esac; shift; done

## Check if the key is present in user's keyring.
if ! have gpg; then
	echo "update-sshauth: gpg not found in \$PATH" >&2
	exit 7
fi

if ! gpg --list-keys "$SIGNER_KEY" &> /dev/null; then
	echo "update-sshauth: $SIGNER_KEY not found in gpg keyring" >&2
	exit 4
fi

update_signer_key >&2 || exit 3

if [ "$SELFUPDATE" = 1 ]; then
	[ "$VERBOSE" == 1 ] && echo "Updating myself"
	tempfile="$( mktemp ~/.ssh/update-sshauth.XXXXXXXXXX )"
	rrfetch "$SELF_URL" "$tempfile" || exit 7
	if verify_sig "$tempfile"; then
		gpg --decrypt "$tempfile" 2> /dev/null | bash -s -- -U "${ARGV[@]}"
	fi
	rm -f "$tempfile"
	exit
fi

tempfile="$( mktemp ~/.ssh/authorized_keys.tmp.XXXXXXXXXX )"
rrfetch "$SOURCE_URL" "$tempfile" || exit 7

if verify_sig "$tempfile"; then
	[ -d ~/.ssh/ ] || mkdir ~/.ssh/
	{
		echo "# updated on $(date "+%a, %d %b %Y %H:%M:%S %z") from $SOURCE_URL"
		gpg --decrypt "$tempfile" 2> /dev/null
	} > ~/.ssh/authorized_keys

	[ "$VERBOSE" == 1 ] && echo "$(grep -c "^ssh-" ~/.ssh/authorized_keys) keys downloaded."
else
	exit 1
fi

## Finally, remove the temporary file.

rm "$tempfile"
