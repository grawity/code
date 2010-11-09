#!bash
# Must be sourced (ie. from bashrc) to be able to change KRB5CCNAME.

kc() {
	local shopt=$(shopt -p failglob nullglob)
	shopt -s nullglob
	shopt -u failglob

	local default="/tmp/krb5cc_$(id -u)"
	local prefix="${default}_"
	local arg=$1; shift
	local ret=0

	local now=$(date +%s)

	local ccaches=("$prefix"*)
	[[ -f $default ]] && ccaches+=("$default")
	[[ -S /var/run/.kcm_socket ]] && ccaches+=("KCM:$(id -u)")

	case $arg in
	list|"")
		local cc= name= ccdata= n=0
		printf '%s\n' "${ccaches[@]}" | sort | while read cc; do
			(( ++n ))
			ccdata="$(pklist -c "$cc" 2>/dev/null)" || continue
			if [[ $cc == $default ]]; then
				name="@"
			else
				name="${cc#$prefix}"
			fi
			local princ= local_realm=
			local in_service= in_expires=0
			local tgt_service= tgt_expires=0
			while IFS=$'\t' read -r item rest; do
				case $item in
				principal)
					princ="$rest"
					local_realm=${princ#*@}
					local_tgt=krbtgt/$local_realm@$local_realm
					;;
				ticket)
					local client service expires flags
					IFS=$'\t' read -r client service _ expires _ flags _ <<< "$rest"
					if [[ $service == $local_tgt ]]; then
						tgt_service=$service
						tgt_expires=$expires
					fi
					if [[ $flags == *I* ]]; then
						in_service=$service
						in_expires=$expires
					fi
					;;
				esac
			done <<< "$ccdata"

			local flag=""

			if [[ $tgt_service ]]; then
				expires=$tgt_expires
			elif [[ $in_service ]]; then
				expires=$in_expires
			fi

			if [[ $expires ]]; then
				if (( expires <= now )); then
					expires_str="(expired)"
					flag="x"
				else
					expires_str=$(date -d "@$expires" +"%b %d, %H:%M")
				fi
			fi

			if [[ -z $flag && $name == "@" && -z $KRB5CCNAME ]]; then
				flag="*"
			elif _kc_eq_ccname "$cc" "$KRB5CCNAME"; then
				flag="»"
			fi

			printf "%1s %2d %-14s%n%-47s%s\n" "$flag" "$n" "$name" pos \
				"$princ" "$expires_str"

			if [[ -z $tgt_service ]] && [[ $in_service ]]; then
				printf "%*s(for %s)\n" $pos "" "$in_service"
			fi
		done
		;;
	purge)
		local ccache= ccdata=
		for file in "${ccaches[@]}"; do
			local ccdata= item= rest=
			local client= service= expiry= flags=
			local realm= tgt= init= expiry=0
			ccdata=$(pklist -c "$ccache") || continue
			while IFS=$'\t' read -r item rest; do
				case $item in
				principal)
					realm=${rest##*@}
					;;
				ticket)
					IFS=$'\t' read -r client service _ expiry _ flags _ <<< "$rest"
					if [[ $client == "*" && $service == "krbtgt/${realm}@${realm}" ]]; then
						# have a local TGT
						tgt=$service
						expiry=$expiry
						break
					elif [[ $client == "*" && $flags == *I* ]]; then
						init=$service
						expiry=$expiry
						break
					fi
					;;
				esac
			done <<< "$ccdata"

			if [[ $tgt ]]; then
				# only ccaches with a TGT can be renewed by kinit
				if ! kinit -c "$ccache" -R; then
					kdestroy -c "$ccache"
				fi
			elif [[ $init ]]; then
				# ccache has an initial ticket but not a TGT
				if (( $expiry < $now )); then
					kdestroy -c "$ccache"
				fi
			else
				if ! kinit -c "$ccache" -R; then
					kdestroy -c "$ccache"
				fi
			fi
		done
		kc list
		;;
	clean)
		rm -vf "$default" "$prefix"*
		;;
	*)
		export KRB5CCNAME=$(_kc_expand "$arg")
		[[ $1 ]] && kinit "$@"
		;;
	esac

	eval "$shopt"
	return $ret
}

_kc_expand() {
	case $1 in
	new)
		printf 'FILE:%s\n' "$(mktemp "${prefix}XXXXXX")";;
	"@")
		printf 'FILE:%s\n' "$default";;
	"-")
		local l=$(_kc_latest);
		[[ $l ]] && printf 'FILE:%s\n' "$l";;
	kcm)
		printf 'KCM:%d\n' "$(id -u)";;
	[0-9]*)
		local i=0
		printf '%s\n' "${ccaches[@]}" | sort | while read -r cc; do
			if (( ++i == $1 )); then
				printf '%s\n' "$cc"
				return
			fi
		done;;
	*)
		printf 'FILE:%s%s\n' "$prefix" "$1";;
	esac
}

_kc_latest() {
	local shopt=$(shopt -p failglob nullglob)
	shopt -s nullglob
	shopt -u failglob

	local files=("$default" "$prefix"*)
	{ command ls -t1 -- "$default" "$prefix"* ||
		echo >&2 "kc: no ccaches"; } | sed 1q

	eval "$shopt"
}

_kc_eq_ccname() {
	local a=$1 b=$2
	a=${a#FILE:}
	b=${b#FILE:}
	[[ $a == $b ]]
}
