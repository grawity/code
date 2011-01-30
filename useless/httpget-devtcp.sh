#!/usr/bin/env bash
get() {
	url="$1"
	host="${url#http://}"
	if [[ "$host" == */* ]]
		then path="/${host#*/}"; host="${host%%/*}"
		else path="/"
	fi
	if [[ "$host" == *:* ]]
		then port="${host#*:}"; host="${host%%:*}"
		else port="80"
	fi

	exec 5<>"/dev/tcp/$host/$port"
	{
	echo -en "GET $path HTTP/1.0\r\n"
	echo -en "Host: $host:$port\r\n"
	echo -en "\r\n"
	} >&5
	read httpver httpstatus httpmsg <&5
	case "$httpstatus" in
	200)
		while true; do
			read line <&5
			[ "$line" = $'\r\n' ] && break;
		done
		cat <&5; exec 5>&-
		;;
	301|302)
		while true; do
			read hdr val <&5
			if [ "${hdr,,}" = "location:" ]; then
				exec 5>&-; get "$val"; break
			elif [ "$hdr" = "" -o "$hdr" = $'\r\n' ]; then
				cat <&5; exec 5>&-; break
			fi
		done
		;;
	#4??|5??)
	*)
		cat <&5 >&2; exec 5>&-; return 1
		;;
	esac
}
get "$1";
