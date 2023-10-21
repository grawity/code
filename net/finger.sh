#!/usr/bin/env bash
# finger.sh -- a multi-backend Finger client

. lib.bash || exit

usage() {
	echo "Usage: $progname [-g] [-l] [user]@host"
	echo ""
	echo_opt "-g" "always use HTTP gateway"
	echo_opt "-l" "long output (/W request)"
}

filter() {
	perl -pe 's/\033/"^".chr(ord($&)+0100)/ge'
}

set -o pipefail

detail=0
webgw=0
ipv6=1

while getopts ":gl" OPT; do
	case $OPT in
	g) webgw=1;;
	l) detail=1;;
	*) lib:die_getopts;;
	esac
done; shift $((OPTIND-1))

query=$1

if (( detail )); then
	query="/W $query"
fi

if [[ $query == *@* ]]; then
	host=${query##*@}
	query=${query%@*}
else
	host=${FINGER_HOST:-localhost}
fi

uquery=$(urlencode -a "$query")
debug "query: '$query' @ '$host'"
debug "query (encoded): '$uquery'"

if [[ $force_client ]]; then
	debug "manually requested mode"
	client=$force_client
elif (( webgw )); then
	debug "requested web gateway"
	client=gateway
elif have python3; then
	debug "found Python 3"
	client=finger.py
elif have curl && curl -V | grep -wqs gopher; then
	debug "found curl with Gopher support"
	client=curl-gopher
elif have curl && curl -V | grep -qws telnet; then
	debug "found curl with Telnet support"
	client=curl-telnet
elif have socat; then
	debug "found Socat"
	client=socat
elif have http-get; then
	debug "found http-get, using web gateway"
	client=gateway
elif have lynx; then
	debug "found Lynx"
	client=lynx
elif have nc; then
	debug "found some-or-other netcat"
	client=nc
else
	die "could not find any usable TCP client"
fi

debug "using client mode '$client'"

if [[ $client == gateway ]]; then
	http-get "http://nullroute.lt/finger/?q=$uquery@$host&raw=1"
elif [[ $client == finger.py ]]; then
	~/bin/net/finger.py "$query@$host"
else
	if have name2addr; then
		debug "found name2addr resolver"
		addrs=($(name2addr -m "$host"))
	elif have getent; then
		debug "found getent resolver"
		addrs=($(getent ahosts "$host" | awk '{print $1}' | sort | uniq))
	else
		debug "no resolver found, using hostname"
	fi

	debug "resolved to [${addrs[@]}]"

	for addr in ${addrs[@]}; do
		debug "trying address '$addr'"

		if have name2addr; then
			rhost=$(name2addr -r "$addr")
		elif have getent; then
			rhost=$(getent hosts "$addr" | awk '{print $3; exit}')
		fi

		debug "reverse-resolved to '${rhost:-$addr}'"
		if [[ "$rhost" == "$host" || "$rhost" == "$addr" ]]; then
			echo "[$addr]"
		else
			echo "[${rhost:-$host}/$addr]"
		fi

		case $client in
		curl-gopher)
			if [[ $addr == *:* ]]; then
				addr="[$addr]"
			fi
			curl -gsS "gopher://$addr:79/0$uquery"
			;;
		curl-telnet)
			if [[ $addr == *:* ]]; then
				addr="[$addr]"
			fi
			printf '%s\r\n' "$query" | curl -gsS "telnet://$addr:79"
			;;
		ncat)
			printf '%s\r\n' "$query" | ncat "$addr" 79
			;;
		socat)
			if [[ $addr == *:* ]]; then
				addr="[$addr]"
			fi
			printf '%s\r\n' "$query" | socat -t10 -T10 stdio "tcp:$addr:79"
			;;
		lynx)
			# adds own header
			if [[ $addr == *:* ]]; then
				addr="[$addr]"
			fi
			lynx -dump -nolist "finger://$addr/$uquery"
			;;
		nc)
			# may be IPv4-only
			printf '%s\r\n' "$query" | nc "$addr" 79
			;;
		*)
			die "bug: unhandled client '$client'"
			;;
		esac && break
	done | filter
fi
