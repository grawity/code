#!bash
# Must be sourced (ie. from bashrc) to be able to change KRB5CCNAME.

kc_list_caches() {
	local current="$(pklist -N)" have_current=
	local default="$(unset KRB5CCNAME; pklist -N)"
	local prefix="/tmp/krb5cc_$(id -u)_"

	local try=("$default")

	local shopt=$(shopt -p failglob nullglob)
	shopt -s nullglob
	shopt -u failglob
	for file in "$prefix"*; do
		try+=("FILE:$file")
	done
	eval "$shopt"

	if [[ -S /var/run/.kcm_socket ]]; then
		try+=("KCM:$(id -u)")
	fi

	for c in "${try[@]}"; do
		if pklist -c "$c" >& /dev/null; then
			printf "%s\n" "$c"
			[[ $c == $current ]] && have_current=$c
		fi
	done > >(sort)
	if [[ ! $have_current ]]; then
		pklist >& /dev/null && printf "%s\n" "$current"
	fi
}

kc() {
	local arg=$1; shift

	local current="$(pklist -N)"
	local default="$(unset KRB5CCNAME; pklist -N)"
	local prefix="/tmp/krb5cc_$(id -u)_"
	local caches; mapfile -t -O 1 -n 99 caches < <(kc_list_caches)

	local now=$(date +%s)

	case $arg in
	-h|--help)
		echo "Usage: kc [list]"
		echo "       kc <name>|\"@\" [kinit_args]"
		;;
	list|"")
		local ccname= dname= ccdata= i= have_current=false
		for (( i=1; i <= ${#caches[@]}; i++ )); do
			ccname=${caches[i]}
			ccdata=$(pklist -c "$ccname") || continue

			local item= rest=
			local flag= defprinc= defrealm= expiry= expiry_str=
			local tgt= init= tgtexpiry=0 initexpiry=0
			while IFS=$'\t' read -r item rest; do
				case $item in
				principal)
					defprinc=$rest
					defrealm=${defprinc##*@}
					;;
				ticket)
					local client= service= expiry= flags=
					IFS=$'\t' read -r client service _ expiry _ flags _ <<< "$rest"

					if [[ $service == "krbtgt/$defrealm@$defrealm" ]]; then
						tgt=$service
						tgtexpiry=$expiry
					fi
					if [[ $flags == *I* ]]; then
						init=$service
						initexpiry=$expiry
					fi
					;;
				esac
			done <<< "$ccdata"

			if [[ $tgt ]]; then
				expiry=$tgtexpiry
			elif [[ $init ]]; then
				expiry=$initexpiry
			fi

			if [[ $expiry ]]; then
				if (( expiry <= now )); then
					expiry_str="(expired)"
					flag="x"
				else
					expiry_str=$(date -d "@$expiry" +"%b %d %H:%M")
				fi
			fi

			if [[ $ccname == $current ]]; then
				if [[ $KRB5CCNAME ]]; then
					flag="»"
				else
					flag="*"
				fi
			fi

			local dname=$ccname
			if [[ $dname == $default ]]; then
				dname="@"
			elif [[ $dname == FILE:${prefix}* ]]; then
				dname="${dname#FILE:${prefix}}"
			elif [[ $dname == API:$defprinc ]]; then
				dname="${dname%$defprinc}*"
			elif [[ $dname == KCM:$(id -u) ]]; then
				dname="KCM"
			fi

			local width=
			if (( ${#dname} > 15 )); then
				printf "%1s%2d %-s\n" "$flag" "$i" "$dname"
				printf "%20s%-48s%s\n" "" "$defprinc" "$expiry_str"
			else
				printf "%1s%2d %-15s %n%-48s%s\n" "$flag" "$i" "$dname" width \
					"$defprinc" "$expiry_str"
			fi
			if [[ $init && $init != "krbtgt/$defrealm@$defrealm" ]]; then
				printf "%*s(for %s)\n" $width "" "$init"
			fi
		done
		;;
	purge)
		local ccname= ccdata=
		for ccname in "${ccaches[@]}"; do
			ccdata=$(pklist -c "$ccname") || continue

			local item= rest=
			local defprinc= defrealm= expiry=
			local tgt= init= tgtexpiry=0 initexpiry=0
			while IFS=$'\t' read -r item rest; do
				case $item in
				principal)
					defprinc=$rest
					defrealm=${princ##*@}
					;;
				ticket)
					local client= service= expiry= flags=
					IFS=$'\t' read -r client service _ expiry _ flags _ <<< "$rest"

					if [[ $service == "krbtgt/$defrealm@$defrealm" ]]; then
						tgt=$service
						tgtexpiry=$expiry
					fi
					if [[ $flags == *I* ]]; then
						init=$service
						initexpiry=$expiry
					fi
					;;
				esac
			done <<< "$ccdata"

			if [[ $tgt ]]; then
				# only ccaches with a TGT can be renewed by kinit
				if ! kinit -c "$ccname" -R; then
					kdestroy -c "$ccname"
				fi
			elif [[ $init ]]; then
				# ccache has an initial ticket but not a TGT
				if (( $initexpiry < $now )); then
					kdestroy -c "$ccname"
				fi
			else
				if ! kinit -c "$ccache" -R; then
					kdestroy -c "$ccname"
				fi
			fi
		done
		kc list
		;;
	clean)
		rm -vf "$default" "$prefix"*
		;;
	*)
		local ccname
		if ccname=$(_kc_expand "$arg"); then
			export KRB5CCNAME=$ccname
			printf "Switched to %s\n" "$KRB5CCNAME"
			[[ $1 ]] && kinit "$@"
		else
			return 1
		fi
		;;
	esac

	true
}

_kc_expand() {
	case $1 in
	new)
		printf 'FILE:%s\n' "$(mktemp "${prefix}XXXXXX")";;
	"@")
		printf '%s\n' "$default";;
	[Kk][Cc][Mm])
		printf 'KCM:%d\n' "$(id -u)";;
	[0-9]|[0-9][0-9])
		local i=$1
		if (( 0 < i && i <= ${#caches[@]} )); then
			printf '%s\n' "${caches[i]}"
		else
			printf '%s\n' "$current"
			echo >&2 "kc: cache #$i not in list"
			return 1
		fi;;
	*:*)
		printf '%s\n' "$1";;
	*/*)
		printf 'FILE:%s\n' "$1";;
	*)
		printf 'FILE:%s%s\n' "$prefix" "$1";;
	esac
}

_kc_eq_ccname() {
	local a=$1 b=$2
	[[ $a == *:* ]] || a=FILE:$a
	[[ $b == *:* ]] || b=FILE:$b
	[[ $a == $b ]]
}
