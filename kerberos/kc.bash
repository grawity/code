#!bash
# NOTE: Must be 'source'd (ie. from bashrc) in order for cache switching to work.

# Translate Unix timestamp to relative time string
_kc_relative_time() {
	local expiry=$1 str=$2 now=$(date +%s)
	local diff=$(( expiry - now ))
	local diff_s=$(( diff % 60 ))
	diff=$(( (diff-diff_s) / 60 ))
	local diff_m=$(( diff % 60 ))
	diff=$(( (diff-diff_m) / 60 ))
	local diff_h=$(( diff % 24 ))
	local diff_d=$(( (diff-diff_h) / 24 ))
	if (( diff_d > 1 )); then
		str+=" ${diff_d} days"
	elif (( diff_h > 0 )); then
		str+=" ${diff_h}h ${diff_m}m"
	elif (( diff_m > 1 )); then
		str+=" ${diff_m} minutes"
	else
		str+=" a minute"
	fi
	echo "$str"
}

# Expand shortname to ccname
_kc_expand_ccname() {
	case $1 in
	"new")
		printf 'FILE:%s\n' "$(mktemp "${ccprefix}XXXXXX")";;
	"@")
		printf '%s\n' "$ccdefault";;
	[Kk][Cc][Mm])
		printf 'KCM:%d\n' "$UID";;
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
		printf 'FILE:%s%s\n' "$ccprefix" "$1";;
	esac
}

# Collapse ccname to shortname
_kc_collapse_ccname() {
	local ccname=$1
	case $ccname in
	"$ccdefault")
		ccname="@";;
	"FILE:$ccprefix"*)
		ccname="${ccname#FILE:$ccprefix}";;
	"FILE:/"*)
		ccname="${ccname#FILE:}";;
	"API:$principal")
		ccname="${ccname%$principal}";;
	"KCM:$UID")
		ccname="KCM";;
	esac
	printf '%s\n' "$ccname"
}

# Compare two ccnames, adding "FILE:" prefix if necessary
_kc_eq_ccname() {
	local a=$1 b=$2
	[[ $a == *:* ]] || a=FILE:$a
	[[ $b == *:* ]] || b=FILE:$b
	[[ $a == $b ]]
}

kc_list_caches() {
	local current="$(pklist -N)" have_current=
	local ccdefault="$(unset KRB5CCNAME; pklist -N)" have_default=

	{
		find "/tmp" -maxdepth 1 -name "krb5cc_*" \( -user "$UID" \
		-o -user "$LOGNAME" \) -printf "FILE:%p\0"
		if [[ -S /var/run/.kcm_socket ]]; then
			printf "%s\0" "KCM:$(id -u)"
		fi
	} | sort -z | {
		while read -rd '' c; do
			if pklist -c "$c" >& /dev/null; then
				printf "%s\n" "$c"
				[[ $c == $current ]] && have_current=$c
				[[ $c == $ccdefault ]] && have_default=$c
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

	local cccurrent=$(pklist -N)
	local ccdefault=$(unset KRB5CCNAME; pklist -N)
	local ccprefix="/tmp/krb5cc_${UID}_"
	local now=$(date +%s)
	local use_color=false

	declare -a caches=()
	readarray -t -O 1 -n 99 caches < <(kc_list_caches)

	[[ $TERM && -t 1 ]] &&
		use_color=true

	local cmd=$1; shift

	case $cmd in
	-h|--help)
		echo "Usage: kc [list]"
		echo "       kc <name>|\"@\" [kinit_args]"
		echo "       kc <number>"
		echo "       kc purge"
		echo "       kc destroy <name|number> ..."
		;;
	"")
		# list ccaches
		local i=

		for (( i=1; i <= ${#caches[@]}; i++ )); do
			local ccname=
			local ccdata=
			local shortname=
			local item=
			local rest=
			local principal=
			local ccrealm=
			local credexpiry=
			local credexpiry_str=
			local tgtexpiry=
			local init=
			local initexpiry=
			local itemflag=
			local itemcolor=
			local flagwidth=
			local colwidth=

			ccname=${caches[i]}
			ccdata=$(pklist -c "$ccname") || continue
			while IFS=$'\t' read -r item rest; do
				case $item in
				principal)
					principal=$rest
					ccrealm=${rest##*@}
					;;
				ticket)
					local tktclient=
					local tktservice=
					local tktexpiry=
					local tktflags=

					IFS=$'\t' read -r tktclient tktservice _ tktexpiry _ flags _ <<< "$rest"
					if [[ $tktservice == "krbtgt/$ccrealm@$ccrealm" ]]; then
						tgtexpiry=$tktexpiry
					fi
					if [[ $tktflags == *I* ]]; then
						init=$tktservice
						initexpiry=$tktexpiry
					fi
					;;
				esac
			done <<< "$ccdata"

			shortname=$(_kc_collapse_ccname "$ccname")

			if (( tgtexpiry )); then
				credexpiry=$tgtexpiry
			elif (( initexpiry )); then
				credexpiry=$initexpiry
			fi

			if (( credexpiry )); then
				if (( credexpiry <= now )); then
					credexpiry_str="(expired)"
					itemflag="x"
					itemcolor=$'\033[31m'
				else
					credexpiry_str=$(_kc_relative_time "$credexpiry" "expires in")
				fi
			fi

			if [[ $ccname == $cccurrent ]]; then
				if [[ $KRB5CCNAME ]]; then
					itemflag="»"
					[[ $itemcolor ]] ||
						itemcolor=$'\033[1;32m'
				else
					itemflag="*"
					[[ $itemcolor ]] ||
						itemcolor=$'\033[32m'
				fi

				if (( credexpiry <= now )); then
					itemcolor=$'\033[33m'
				fi
			fi

			if $use_color; then
				[[ $itemflag ]] && itemflag="${itemcolor}${itemflag}"$'\033[m'
			fi

			if (( ${#shortname} > 15 )); then
				printf '%1s%n%2d %s\n' "$itemflag" flagwidth "$i" "$shortname"
				printf '%20s%-48s%s\n' "" "$principal" "$credexpiry_str"
			else
				printf '%1s%n%2d %-15s %n%-48s%s\n' "$itemflag" flagwidth "$i" "$shortname" \
					colwidth "$principal" "$credexpiry_str"
			fi
			(( colwidth += (1 - flagwidth) ))
			if [[ $init && $init != "krbtgt/$ccrealm@$ccrealm" ]]; then
				printf '%*s(for %s)\n' "$colwidth" "" "$init"
			fi
		done
		;;
	purge)
		local ccname=
		local ccdata=

		for ccname in "${caches[@]}"; do
			local principal=$(pklist -c "$ccname" -P)
			echo "Renewing credentials for $principal in $ccname"
			kinit -c "$ccname" -R || kdestroy -c "$ccname"
		done
		;;
	destroy)
		local shortname=
		local ccname=
		local destroy=()

		for shortname; do
			if ccname=$(_kc_expand_ccname "$shortname"); then
				destroy+=("$ccname")
			fi
		done
		for ccname in "${destroy[@]}"; do
			kdestroy -c "$ccname"
		done
		;;
	clean)
		rm -vf "$ccdefault" "$ccprefix"*
		;;
	list)
		printf '%s\n' "${caches[@]}"
		;;
	=*)
		local line=

		if line=$(grep -w "^${arg#=}" ~/lib/kerberos); then
			eval kc "$line"
		fi
		;;
	?*@?*)
		local ccname=
		local maxexpiry=
		local maxccname=

		for ccname in "${caches[@]}"; do
			local ccdata=
			local item=
			local rest=
			local principal=
			local ccrealm=
			local tgtexpiry=
			local initexpiry=

			principal=$(pklist -Pc "$ccname") &&
				[[ $defprinc == $arg ]] || continue

			ccrealm=${principal##*@}

			ccdata=$(pklist -c "$ccname") || continue
			while IFS=$'\t' read -r item rest; do
				case $item in
				ticket)
					local tktclient=
					local tktservice=
					local tktexpiry=
					local tktflags=

					IFS=$'\t' read -r tktclient tktservice _ tktexpiry _ tktflags <<< "$rest"
					if [[ $tktservice == "krbtgt/$ccrealm@$ccrealm" ]]; then
						tgtexpiry=$tktexpiry
					fi
					if [[ $flags == *I* ]]; then
						initexpiry=$tktexpiry
					fi
					;;
				esac
			done <<< "$ccdata"

			if (( tgtexpiry )); then
				credexpiry=$tgtexpiry
			elif (( initexpiry )); then
				credexpiry=$initexpiry
			fi

			if (( expiry > maxexpiry )); then
				maxexpiry=$expiry
				maxccname=$ccname
			fi
		done

		if [[ $maxccname ]]; then
			export KRB5CCNAME=$maxccname
			printf "Switched to %s\n" "$KRB5CCNAME"
		else
			export KRB5CCNAME=$(_kc_expand_ccname 'new')
			printf "Switched to %s\n" "$KRB5CCNAME"
			kinit "$cmd" "$@"
		fi
		;;
	*)
		local ccname=

		if ccname=$(_kc_expand_ccname "$cmd"); then
			export KRB5CCNAME=$ccname
			printf "Switched to %s\n" "$KRB5CCNAME"
			[[ $1 ]] && kinit "$@"
		else
			return 1
		fi
		;;
	esac
	return 0
}
