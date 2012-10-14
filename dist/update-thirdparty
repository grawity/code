#!/usr/bin/env bash
dir="$HOME/code/thirdparty"
list="$dir/update.txt"

grep '^[^#]' "$list" | while read -r file url mode; do
	echo "$url → $file"
	path="$dir/$file"
	curl -s -L -z "$path" "$url" -o "$path"
	if [[ $mode ]]; then
		chmod "$mode" "$path"
	fi
done
