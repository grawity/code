#!bash
# Must be sourced (ie. from bashrc) to be able to change KRB5CCNAME.

kc_list_caches() {
	local current="$(pklist -N)" have_current=
	local default="$(unset KRB5CCNAME; pklist -N)" have_default=

	{
		find "/tmp" -maxdepth 1 -name "krb5cc_*" \( -user "$(id -un)" \
		-o -user "$LOGNAME" \) -printf "FILE:%p\0"
		if [[ -S /var/run/.kcm_socket ]]; then
			printf "%s\0" "KCM:$(id -u)"
		fi
	} | sort -z | {
		while read -rd '' c; do
			if pklist -c "$c" >& /dev/null; then
				printf "%s\n" "$c"
				[[ $c == $current ]] && have_current=$c
				[[ $c == $default ]] && have_default=$c
			fi
		done
		if [[ ! $have_current ]]; then
			pklist >& /dev/null && printf "%s\n" "$current"
		fi
	}
}

kc() {
	if ! command -v pklist >&/dev/null; then
		echo "'pklist' not found in \$PATH" >&2
		return 2
	fi

	local arg=$1; shift

	local current="$(pklist -N)"
	local default="$(unset KRB5CCNAME; pklist -N)"
	local prefix="/tmp/krb5cc_$(id -u)_"
	local caches; mapfile -t -O 1 -n 99 caches < <(kc_list_caches)

	local now=$(date +%s)
	local use_color=false
	[[ $TERM && -t 1 ]] && use_color=true

	case $arg in
	-h|--help)
		echo "Usage: kc [list]"
		echo "       kc <name>|\"@\" [kinit_args]"
		echo "       kc <number>"
		echo "       kc purge"
		echo "       kc destroy <name|number> ..."
		;;
	"")
		local ccname= dname= ccdata= i= have_current=false
		for (( i=1; i <= ${#caches[@]}; i++ )); do
			ccname=${caches[i]}
			ccdata=$(pklist -c "$ccname") || continue

			local item= rest=
			local flag= defprinc= defrealm= expiry= expiry_str=
			local tgt= init= tgtexpiry=0 initexpiry=0
			local flag_color=

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
					flag_color=$'\033[31m'
				else
					expiry_str=$(date -d "@$expiry" +"%b %d %H:%M")
				fi
			fi

			if [[ $ccname == $current ]]; then
				if [[ $KRB5CCNAME ]]; then
					flag="»"
					flag_color=$'\033[1;32m'
				else
					flag="*"
					flag_color=$'\033[32m'
				fi
				if [[ $expiry_str == "(expired)" ]]; then
					flag_color=$'\033[33m'
				fi
			fi

			$use_color && [[ $flag ]] && flag=${flag_color}${flag}$'\033[m'

			local dname=$ccname
			if [[ $dname == $default ]]; then
				dname="@"
			elif [[ $dname == FILE:${prefix}* ]]; then
				dname="${dname#FILE:${prefix}}"
			elif [[ $dname == FILE:/* ]]; then
				dname="${dname#FILE:}"
			elif [[ $dname == API:$defprinc ]]; then
				dname="${dname%$defprinc}*"
			elif [[ $dname == KCM:$(id -u) ]]; then
				dname="KCM"
			fi

			local width=20 flag_w=1
			if (( ${#dname} > 15 )); then
				printf "%1s%n%2d %-s\n" "$flag" flag_w "$i" "$dname"
				printf "%20s%-48s%s\n" "" "$defprinc" "$expiry_str"
			else
				printf "%1s%n%2d %-15s %n%-48s%s\n" "$flag" flag_w "$i" "$dname" width \
					"$defprinc" "$expiry_str"
			fi
			(( width += (1 - flag_w) ))
			if [[ $init && $init != "krbtgt/$defrealm@$defrealm" ]]; then
				printf "%*s(for %s)\n" $width "" "$init"
			fi
		done
		;;
	purge)
		local ccname= ccdata=
		for ccname in "${caches[@]}"; do
			ccdata=$(pklist -c "$ccname") || continue

			local item= rest=
			local defprinc= defrealm= expiry=
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
				# only TGTs are renewable
				if ! kinit -c "$ccname" -R; then
					kdestroy -c "$ccname"
				fi
			elif [[ $init ]]; then
				# ccache has an initial ticket but not a TGT
				if (( $initexpiry < $now )); then
					kdestroy -c "$ccname"
				fi
			else
				if ! kinit -c "$ccname" -R; then
					kdestroy -c "$ccname"
				fi
			fi
		done
		;;
	destroy)
		local name ccname ccnames=()
		# kdestroying immediately would break numbered names
		for name; do
			if ccname=$(_kc_expand "$name"); then
				ccnames+=("$ccname")
			fi
		done
		for ccname in "${ccnames[@]}"; do
			kdestroy -c "$ccname"
		done
		;;
	clean)
		rm -vf "$default" "$prefix"*
		;;
	list)
		printf '%s\n' "${caches[@]}"
		;;
	expand)
		_kc_expand "$1"
		;;
	=*)
		local line=
		if line=$(grep -w "^${arg#=}" ~/lib/kerberos); then
			eval kc "$line"
		fi
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
