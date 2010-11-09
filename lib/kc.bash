#!bash
# Must be sourced (ie. from bashrc) to be able to change KRB5CCNAME.

kc_list_caches() {
	local default="$(unset KRB5CCNAME; pklist -N)"
	local prefix="/tmp/krb5cc_$(id -u)_"

	if [[ $default == FILE:* ]]; then
		[[ -f ${default#FILE:} ]] && printf "%s\n" "$default"
	fi

	local shopt=$(shopt -p failglob nullglob)
	shopt -s nullglob
	shopt -u failglob
	for file in "$prefix"*; do
		[[ -f $file ]] && printf "FILE:%s\n" "$file"
	done
	eval "$shopt"

	if [[ -S /var/run/.kcm_socket ]]; then
		local c="KCM:$(id -u)"
		pklist -c "$c" >& /dev/null && printf "%s\n" "$c"
	fi
}

kc() {
	local arg=$1; shift

	local default="$(unset KRB5CCNAME; pklist -N)"
	local prefix="/tmp/krb5cc_$(id -u)_"
	local caches; mapfile -t -O 1 -n 99 caches < <(kc_list_caches | sort)

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
					expiry_str=$(date -d "@$expiry" +"%b %d, %H:%M")
				fi
			fi

			if [[ -z $flag && -z $KRB5CCNAME && $dname == "@" ]]; then
				have_current=true
				flag="*"
			elif _kc_eq_ccname "$ccname" "$KRB5CCNAME"; then
				have_current=true
				flag="»"
			fi

			local dname=$ccname
			if [[ $dname == $default ]]; then
				dname="@"
			elif [[ $dname == FILE:${prefix}* ]]; then
				dname="${dname#FILE:${prefix}}"
			elif [[ $dname == API:$defprinc ]]; then
				dname="${dname%$defprinc}"
			elif [[ $dname == KCM:$(id -u) ]]; then
				dname="KCM"
			fi

			local width=
			printf "%1s%2d %-16s%n%-49s%s\n" "$flag" "$i" "$dname" width \
				"$defprinc" "$expiry_str"
			if [[ $init != "krbtgt/$defrealm@$defrealm" ]]; then
				printf "%*s(for %s)\n" $width "" "$init"
			fi
		done

		if ! $have_current; then
			klist
		fi
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
		export KRB5CCNAME=$(_kc_expand "$arg")
		[[ $1 ]] && kinit "$@"
		;;
	esac
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
		printf '%s\n' "${caches[i]}";;
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
