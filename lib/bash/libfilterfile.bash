# vim: ft=sh
# libfilterfile.bash - filter a text file using cpp-like #if/#endif statements

. lib.bash || exit

filter_file() {
	local -- func='' line='' cond='' dp=''
	local -i verbose=0 nr=0 depth=0
	local -ai stack=(1) elif=() else=()
	if [[ $1 == -v ]]; then
		verbose=1; shift
	fi
	func=${1:-false}
	debug "use FILTERDEBUG=1 to see the final result"
	while IFS='' read -r line; do
		printf -v dp '%-3d:%*s' $((++nr)) $((depth*2)) ''
		if [[ $line == '#'* ]]; then
			trace "${dp}${line%% *}... ($depth:[${stack[*]}])"
		fi

		if [[ $line == '#if '* ]]; then
			if (( stack[depth++] )) && $func "${line#* }"; then
				stack[depth]=1
				elif[depth]+=1
			else
				stack[depth]=0
			fi
			if (( verbose )); then echo "$line"; fi
		elif [[ $line == '#elif '* ]]; then
			if (( !depth )); then
				err "line $nr: '#elif' directive outside '#if' was ignored"
			elif (( else[depth] )); then
				warn "line $nr: '#elif' block after '#else' will be skipped"
				stack[depth]=0
			elif (( stack[depth-1] && !elif[depth] )) && $func "${line#* }"; then
				stack[depth]=1
				elif[depth]+=1
			else
				stack[depth]=0
			fi
			if (( verbose )); then echo "$line"; fi
		elif [[ $line == '#else' ]]; then
			if (( !depth )); then
				err "line $nr: '#else' directive outside '#if' was ignored"
			elif (( else[depth]++ )); then
				warn "line $nr: duplicate '#else' block will be skipped"
				stack[depth]=0
			elif (( stack[depth-1] && !elif[depth] )); then
				stack[depth]=1
				elif[depth]+=1
			else
				stack[depth]=0
			fi
			if (( verbose )); then echo "$line"; fi
		elif [[ $line == '#endif' ]]; then
			if (( !depth )); then
				err "line $nr: '#endif' directive outside '#if' was ignored"
			else
				unset elif[depth]
				unset else[depth]
				unset stack[depth--]
			fi
			if (( verbose )); then echo "$line"; fi
		elif [[ $line == '#'[a-z]* ]]; then
			warn "line $nr: unknown directive '${line%% *}' was ignored"
			continue
		elif (( stack[depth] )); then
			if (( FILTERDEBUG )); then
				printf '\e[92m++\e[;m %s\e[m\n' "$line" >&2
			fi
			echo "$line"
		else
			if (( FILTERDEBUG )); then
				printf '\e[91m--\e[;2m %s\e[m\n' "$line" >&2
			fi
			if (( verbose )); then echo "#OFF# $line"; fi
		fi

		if [[ $line == '#'* ]]; then
			trace "${dp}${line%% *} => $depth:[${stack[*]}]"
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
