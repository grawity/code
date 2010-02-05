#!/bin/bash
SOURCE_DIR="http://purl.oclc.org/NET/grawity/misc/"
if [ "$( id -u )" -eq 0 ]
	then SOURCE_URL="${SOURCE_DIR}authorized_keys_root.txt"
	else SOURCE_URL="${SOURCE_DIR}authorized_keys.txt"
fi
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

gpgst() { gpg --status-fd=3 3>&1 >& /dev/null "$@"; }

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
	elif have php && php -i | grep -qsi '^allow_url_fopen => on'; then
		php -r 'echo file_get_contents(urlencode($argv[1])), FILE_BINARY);' "$URL" > "$OUT"
	elif have php && php -i | grep -qs '^curl$'; then
		php -r '$ch = curl_init($argv[1]); curl_setopt($ch, CURLOPT_FOLLOWLOCATION, 1); curl_exec($ch);' "$URL" > "$OUT"
	elif have tclsh; then
		tclsh - <<< 'package require http; fconfigure stdout -translation binary; puts -nonewline [http::data [http::geturl [lindex $argv 1]]]' "$URL" > "$OUT"
	else
		# Damn.
		echo "sshup: no download tool available" >&2
		exit 3
	fi
}

# download a GPG public key
gpg_recv_key() {
	local keyid="$1" server="$2"
	local out="$( gpgst --keyserver "$server" --recv-key "$keyid" )"
	if ! grep -qs "^\[GNUPG:\] IMPORT_OK " <<< "$out"; then
		echo "$out" >&2
		return 1
	fi
	return 0
}

# update signer's GPG pubkey, retrying several keyservers
update_signer_key() {
	$VERBOSE && echo "sshup: updating signer key $SIGNER_KEY"
	for server in "${KEYSERVERS[@]}"; do
		$VERBOSE && echo "sshup: * trying $server"
		if gpg_recv_key "$SIGNER_KEY" "$server"
			then return 0
			else sleep 3
		fi
	done
	return 1
}

rrfetch() {
	local url="$1" output="$2"
	local max_retries=5 retry_wait=3 attempt=0
	while [ $(( ++attempt )) -le $max_retries ]; do
		$VERBOSE && echo "sshup: fetching $url (attempt $attempt)"
		http_fetch "$url" "$output"
		if [ -s "$output" ]
			then return 0
			else rm -f "$output"; sleep $retry_wait
		fi
	done
	rm -f "$output"
	return 1
}

verify_sig() {
	local input="$1"
	local out="$( gpgst --verify "$input" )"
	if grep -Eqs "^\\[GNUPG:\\] (ERROR|NODATA|BADSIG)( |\$)" <<< "$out" ||
		! grep -qs "^\\[GNUPG:\\] GOODSIG $SIGNER_KEY " <<< "$out" ||
		! grep -qs "^\\[GNUPG:\\] TRUST_ULTIMATE\$" <<< "$out"
	then
		{ echo "sshup: gpg $@"; echo "$out"; } >&2
		return 1
	else
		$VERBOSE && echo "$out"
		return 0
	fi
}

VERBOSE=false
SELFUPDATE=true
while getopts "vrU" option "$@"; do
	case "$option" in
	v) VERBOSE=true ;;
	r) update_signer_key && echo -e "5\ny" | gpg --edit-key "$SIGNER_KEY" trust quit ;;
	U) SELFUPDATE=false ;;
	?) echo "sshup: unknown option $1" ;;
	esac
done

## Check if the key is present in user's keyring.
if ! have gpg; then
	echo "sshup: gpg not found in \$PATH" >&2
	exit 1
fi

if ! gpg --list-keys "$SIGNER_KEY" &> /dev/null; then
	echo "sshup: $SIGNER_KEY not found in gpg keyring" >&2
	exit 1
fi

update_signer_key >&2 || exit 1

if $SELFUPDATE; then
	$VERBOSE && echo "sshup/$$: updating myself"
	tempfile="$( mktemp ~/.ssh/update-sshauth.gpg.XXXXXXXXXX )"
	tempout="$( mktemp ~/.ssh/update-sshauth.sh.XXXXXXXXXX )"
	rrfetch "$SELF_URL" "$tempfile" || exit 1
	if gpgst --yes -o "$tempout" -d "$tempfile"; then 
		$VERBOSE && echo "sshup/$$: calling $tempout"
		bash -- "$tempout" -U "$@"
	fi
	rm -f "$tempfile" "$tempout"
else
	tempfile="$( mktemp ~/.ssh/authorized_keys.XXXXXXXXXX )"
	rrfetch "$SOURCE_URL" "$tempfile" || exit 1
	verify_sig "$tempfile" || exit 1
	{
		echo "# updated on $(date "+%a, %d %b %Y %H:%M:%S %z") from $SOURCE_URL"
		gpg --decrypt "$tempfile" 2> /dev/null
	} > ~/.ssh/authorized_keys
	$VERBOSE && echo "sshup/$$: $(grep -c "^ssh-" ~/.ssh/authorized_keys) keys downloaded"
	rm -f "$tempfile"
fi
