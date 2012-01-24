#!bash
# libfilterfile.bash - filter a text file using cpp-like #if/#endif statements

. lib.bash

filter_file() {
	local maskfunc=${1:-false}
	local line='' masked=false mask='' matched=false skipped=0
	while IFS='' read -r line; do
		if [[ $line == '#if '* ]]; then
			masked=true
			mask=${line#'#if '}
			debug "matching '$mask' using '$maskfunc'"
			if $maskfunc "$mask"; then
				matched=true
			else
				matched=false
			fi
			skipped=0
			debug "start masked region, mask='$mask', matched=$matched"
			continue
		elif [[ $line == '#endif' ]]; then
			masked=false
			debug "end masked region, skipped $skipped lines"
			continue
		elif $masked && ! $matched; then
			((++skipped))
			continue
		else
			echo "$line"
		fi
	done
}

match_hostname() {
	local mask=${1:-*}
	debug "matching '$FQDN', '$HOSTNAME' against '$mask'"
	(shopt -s extglob;
		[[ $FQDN == $mask || $HOSTNAME == $mask ]])
}
