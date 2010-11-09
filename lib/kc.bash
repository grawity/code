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

	local files=("$prefix"*)
	[[ -f $default ]] && files+=("$default")

	case $arg in
	list|"")
		if [[ $files ]]; then
			local file=
			command ls -tr1 "${files[@]}" | while read -r file; do
				local name=""
				if [[ $file == $default ]]; then
					name="@"
				else
					name="${file#$prefix}"
				fi

				local ccdata="$(pklist -c "FILE:$file")"
				local princ="" local_realm=""
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
						local client service issue expires renew flags
						IFS=$'\t' read -r client service issue expires renew flags _ <<< "$rest"
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
				elif _kc_eq_ccname "$file" "$KRB5CCNAME"; then
					flag="»"
				fi

				printf "%1s %-14s%-48s%s\n" "$flag" "$name" \
					"$princ" "$expires_str"

				if [[ -z $tgt_service ]] && [[ $in_service ]]; then
					printf "%16s(for %s)\n" "" "$in_service"
				fi
			done
		else
			echo >&2 "kc: no ccaches"
			ret=1
		fi
		;;
	purge)
		local file= kept=0 removed=0
		for file in "${files[@]}"; do
			if klist -c "$file" -s || kinit -c "$file" -R; then
				(( ++kept ))
			else
				kdestroy -c "$file"
				rm -f "$file"
				(( ++removed ))
			fi
		done
		echo "$kept ccaches kept, $removed removed"
		kc list
		;;
	clean)
		rm -vf "$default" "$prefix"*
		;;
	*)
		export KRB5CCNAME=$(_kc_expand "$arg")
		klist -s || kinit "$@"
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
