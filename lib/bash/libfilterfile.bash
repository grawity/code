# vim: ft=sh
# libfilterfile.bash - filter a text file using cpp-like #if/#endif statements

. lib.bash || exit

filter_file() {
	local func=${1:-false}
	local line='' nr=0 cond='' current=true stack=(true) else=() depth=0 d
	while IFS='' read -r line; do
		printf -v d '%-3d:%*s' $((++nr)) $((depth*2)) ''
		if [[ $line == '#'* ]]; then
			debug "$d${line%% *}... ($depth:[${stack[*]}], $current)"
		fi

		if [[ $line == '#if '* ]]; then
			# eval & push
			$current && $func "${line#* }" || current=false
			stack[++depth]=$current
		elif [[ $line == '#elif '* ]]; then
			if (( !depth )); then
				err "line $nr: '#elif' directive outside '#if' was ignored"
				continue
			elif (( else[depth] )); then
				warn "line $nr: '#elif' block after '#else' will be skipped"
			fi
			if ${stack[depth]}; then
				current=false
			else
				# pop
				unset stack[depth--]
				current=${stack[depth]}
				# eval & push
				$current && $func "${line#* }" || current=false
				stack[++depth]=$current
			fi
		elif [[ $line == '#else' ]]; then
			if (( !depth )); then
				err "line $nr: '#else' directive outside '#if' was ignored"
				continue
			elif (( else[depth]++ )); then
				warn "line $nr: duplicate '#else' block will be skipped"
			fi
			if ${stack[depth-1]} && ! ${stack[depth]}; then
				# swap
				current=true
				stack[depth]=$current
			else
				current=false
			fi
		elif [[ $line == '#endif' ]]; then
			if (( !depth )); then
				err "line $nr: '#endif' directive outside '#if' was ignored"
				continue
			fi
			else[depth]=0
			# pop
			unset stack[depth--]
			current=${stack[depth]}
		elif [[ $line == '#'[a-z]* ]]; then
			err "line $nr: unknown directive '${line%% *}' was ignored"
			continue
		elif $current; then
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
			debug "$d${line%% *} => $depth:[${stack[*]}], $current"
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
