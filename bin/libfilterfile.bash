#!bash
# libfilterfile.bash - filter a text file using cpp-like #if/#endif statements

. lib.bash || exit

filter_file() {
	local maskfunc=${1:-false}
	local line='' masked=false mask='' matched=false skipped=0 matchedconds=0
	while IFS='' read -r line; do
		if [[ $line == '#if '* ]]; then
			masked=true
			mask=${line#'#if '}
			debug "matching '$mask' using '$maskfunc'"
			if $maskfunc "$mask"; then
				matched=true
				((++matchedconds))
			else
				matched=false
			fi
			skipped=0
			debug "start masked region, mask='$mask', matched=$matched"
			continue
		elif [[ $line == '#else' ]]; then
			if ! $masked; then
				warn "'#else' region outside '#if'"
				continue
			fi

			if ((matchedconds == 0)); then
				debug "start else region"
				matched=true
				continue
			else
				debug "skip else region"
				matched=false
				continue
			fi
		elif [[ $line == '#endif' ]]; then
			masked=false
			matchedconds=0
			debug "end masked region, skipped $skipped lines"
			continue
		elif $masked && ! $matched; then
			((++skipped))
			continue
		else
			if [[ $line == '#'[a-z]* ]]; then
				warn "unknown directive '${line%% *}' ignored"
			fi
			echo "$line"
		fi
	done
	if $masked; then
		warn "missing '#endif' after '#if $mask'"
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
