# vim: ft=sh

http_fetch() {
	local url=$1 out=${2:-/dev/stdout}
	if ! [[ $url && $url == "http://"* ]]; then
		err "non-http URL given"
		return 99
	elif have curl; then
		debug "found curl"
		curl -gLSsf -o "$out" "$url"
	elif have wget; then
		debug "found wget"
		wget -q -O "$out" "$url"
	elif have lynx; then
		debug "found lynx"
		lynx -source "$url" > "$out"
	elif have w3m; then
		debug "found w3m"
		w3m -o 'auto_uncompress=1' -dump_source "$url" > "$out"
	elif have fetch; then
		debug "found libfetch"
		fetch -o "$out" "$url"
	elif have gio; then
		debug "found gio"
		gio cat "$url" > "$out"
	elif have gvfs-copy && [[ -f $out || ! -e $out ]]; then
		debug "found gvfs-copy"
		gvfs-copy "$url" "$out"
	elif have gvfs-cat; then
		debug "found gvfs-cat"
		gvfs-cat "$url" > "$out"
	elif have links; then
		debug "found Links"
		links -source "$url" > "$out"
	elif have elinks; then
		debug "found ELinks"
		elinks -source "$url" > "$out"
	elif have php && php -r 'exit((int) !function_exists("curl_init"));'; then
		debug "found PHP with cURL"
		php -d 'safe_mode=Off' -- "$url" > "$out" <<-'EOF'
			<?php
			$ch = curl_init($argv[1]);
			curl_setopt($ch, CURLOPT_FOLLOWLOCATION, 1);
			curl_exec($ch);
		EOF
	elif have php; then
		debug "found PHP (using url_fopen)"
		php -d 'allow_url_fopen=On' -r '@readfile($argv[1]);' "$url" > "$out"
	elif have python2; then
		debug "found Python 2 (using urllib)"
		python2 - "$url" > "$out" <<-'EOF'
			import sys, urllib2
			try: sys.stdout.write(urllib2.urlopen(sys.argv[1]).read())
			except: sys.exit(1)
		EOF
	elif have perl && perl -m'LWP::Simple' -e'1' 2> /dev/null; then
		debug "found Perl with LWP::Simple"
		perl -M'LWP::Simple' -e'getstore $ARGV[0], $ARGV[1]' "$url" "$out"
	elif have tclsh; then
		debug "found Tcl (using http)"
		tclsh - "$url" > "$out" <<-'EOF'
			package require http
			fconfigure stdout -translation binary
			puts -nonewline [http::data [http::geturl [lindex $argv 1]]]
		EOF
	else
		err "no HTTP client available"
		return 99
	fi
	[[ ! -f $out || -s $out ]] # fail if output file empty
}
