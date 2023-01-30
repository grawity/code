# vim: ft=sh
# libfilterfile.bash - filter a text file using cpp-like #if/#endif statements

. lib.bash || exit

filter_file() {
	local -- func=${1:-false} dfmt='' line='' cond=''
	local -i nr=0 depth=0
	local -ai stack=(1) elif=() else=()
	local -A dfmts=(
		[err]='\e[30;41m!!'
		[warn]='\e[93m??\e[;93m'
		[condok]='\e[95m>>\e[;35m'
		[condfail]='\e[94m<<\e[;34m'
		[vis]='\e[92m +\e[m'
		[invis]='\e[91m -\e[;2m'
	)
	debug "use FILTERDEBUG=1 to see the final result"
	while IFS='' read -r line; do
		if [[ $line == '#if '* ]]; then
			if (( stack[depth++] )) && $func "${line#* }"; then
				stack[depth]=1
				elif[depth]+=1
				dfmt=condok
			else
				stack[depth]=0
				dfmt=condfail
			fi
		elif [[ $line == '#elif '* ]]; then
			if (( !depth )); then
				err "line $nr: '#elif' directive outside '#if' was ignored"
				dfmt=err
			elif (( else[depth] )); then
				err "line $nr: '#elif' block after '#else' will be skipped"
				stack[depth]=0
				dfmt=err
			elif (( stack[depth-1] && !elif[depth] )) && $func "${line#* }"; then
				stack[depth]=1
				elif[depth]+=1
				dfmt=condok
			else
				stack[depth]=0
				dfmt=condfail
			fi
		elif [[ $line == '#else' ]]; then
			if (( !depth )); then
				err "line $nr: '#else' directive outside '#if' was ignored"
				dfmt=err
			elif (( else[depth]++ )); then
				err "line $nr: duplicate '#else' block will be skipped"
				stack[depth]=0
				dfmt=err
			elif (( stack[depth-1] && !elif[depth] )); then
				stack[depth]=1
				elif[depth]+=1
				dfmt=condok
			else
				stack[depth]=0
				dfmt=condfail
			fi
		elif [[ $line == '#endif' ]]; then
			if (( !depth )); then
				err "line $nr: '#endif' directive outside '#if' was ignored"
				dfmt=err
			else
				unset elif[depth]
				unset else[depth]
				unset stack[depth--]
				dfmt=condok
			fi
		elif [[ $line == '#'[a-z]* ]]; then
			warn "line $nr: unknown directive '${line%% *}'"
			dfmt=warn
		elif (( stack[depth] )); then
			echo "$line"
			dfmt=vis
		else
			dfmt=invis
		fi
		if (( FILTERDEBUG )); then
			printf "${dfmts[$dfmt]} %s\e[m\n" "$line" >&2
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
	local arg=${1:-*}
	local mask=${arg#!}; mask=${mask// }
	debug "matching fqdn='$FQDN', host='$HOSTNAME' against extglob '$mask'"
	if (shopt -s extglob; [[ $FQDN == $mask || $HOSTNAME == $mask ]])
	then [[ $arg != !* ]]
	else [[ $arg == !* ]]
	fi
}
