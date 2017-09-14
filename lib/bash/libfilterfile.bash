# vim: ft=sh
# libfilterfile.bash - filter a text file using cpp-like #if/#endif statements

. lib.bash || exit

filter_file() {
	local -- func=${1:-false}
	local -- line='' cond='' d=''
	local -i nr=0 depth=0
	local -ai stack=(1) elif=() else=()
	while IFS='' read -r line; do
		printf -v d '%-3d:%*s' $((++nr)) $((depth*2)) ''
		if [[ $line == '#'* ]]; then
			debug "$d${line%% *}... ($depth:[${stack[*]}])"
		fi

		if [[ $line == '#if '* ]]; then
			if (( stack[depth++] )) && $func "${line#* }"; then
				stack[depth]=1
			else
				stack[depth]=0
			fi
		elif [[ $line == '#elif '* ]]; then
			if (( !depth )); then
				err "line $nr: '#elif' directive outside '#if' was ignored"
			elif (( else[depth] )); then
				warn "line $nr: '#elif' block after '#else' will be skipped"
				stack[depth]=0
			elif (( stack[depth-1] && !stack[depth] && !elif[depth] )) && $func "${line#* }"; then
				stack[depth]=1
				elif[depth]+=1
			else
				stack[depth]=0
			fi
		elif [[ $line == '#else' ]]; then
			if (( !depth )); then
				err "line $nr: '#else' directive outside '#if' was ignored"
			elif (( else[depth]++ )); then
				warn "line $nr: duplicate '#else' block will be skipped"
				stack[depth]=0
			elif (( stack[depth-1] && !stack[depth] && !elif[depth] )); then
				stack[depth]=1
				elif[depth]+=1
			else
				stack[depth]=0
			fi
		elif [[ $line == '#endif' ]]; then
			if (( !depth )); then
				err "line $nr: '#endif' directive outside '#if' was ignored"
				continue
			fi
			unset elif[depth]
			unset else[depth]
			unset stack[depth--]
		elif [[ $line == '#'[a-z]* ]]; then
			err "line $nr: unknown directive '${line%% *}' was ignored"
			continue
		elif (( stack[depth] )); then
			if (( DEBUG >= 2 )); then
				echo $'\e[1;36m'"+++ $line"$'\e[m' >&2
			fi
			echo "$line"
		else
			if (( DEBUG >= 2 )); then
				echo $'\e[1;35m'"--- $line"$'\e[m' >&2
			fi
		fi

		if [[ $line == '#'* ]]; then
			debug "$d${line%% *} => $depth:[${stack[*]}]"
		fi
	done
	if (( depth )); then
		warn "line $nr: missing '#endif' directive (depth $depth at EOF)"
	fi
}

match_eval() {
	local code=$1
	debug "evaluating '$code'"
	(eval "$code")
}

match_hostname() {
	local mask=${1:-*}
	debug "matching fqdn='$FQDN', host='$HOSTNAME' against '$mask'"
	(shopt -s extglob;
		[[ $FQDN == $mask || $HOSTNAME == $mask ]])
}
