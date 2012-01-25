#!bash
http_fetch() {
	local url="$1" out="${2:-/dev/stdout}"
	if have curl; then
		curl -LSsf -o "$out" "$url"
	elif have wget; then
		wget -q -O "$out" "$url"
	elif have lynx; then
		lynx -source "$url" > "$out"
	elif have w3m; then
		w3m -o 'auto_uncompress=1' -dump_source "$url" > "$out"
	elif have links; then
		links -source "$url" > "$out"
	elif have elinks; then
		elinks -source "$url" > "$out"
	elif have python; then
		python - "$url" > "$out" <<-'EOF'
			import sys, urllib2
			try: sys.stdout.write(urllib2.urlopen(sys.argv[1]).read())
			except: sys.exit(1)
		EOF
	elif have php && php -i | grep -qs '^curl$' 2>/dev/null; then
		php -d 'safe_mode=Off' -- "$url" > "$out" <<-'EOF'
			<?php
			$ch = curl_init($argv[1]);
			curl_setopt($ch, CURLOPT_FOLLOWLOCATION, 1);
			curl_exec($ch);
		EOF
	elif have php; then
		php -d 'allow_url_fopen=On' -r '@readfile($argv[1]);' "$url" > "$out"
	elif have perl && perl -mLWP::Simple -e'1' 2> /dev/null; then
		perl -mLWP::Simple -e'getstore $ARGV[0], $ARGV[1]' "$url" "$out"
	elif have tclsh; then
		tclsh - "$url" > "$out" <<-'EOF'
			package require http
			fconfigure stdout -translation binary
			puts -nonewline [http::data [http::geturl [lindex $argv 1]]]
		EOF
	else
		echo "no HTTP client available" >&2
		return 1
	fi
	[ -s "$out" ] # fail if output file empty
}
