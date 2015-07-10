#!/usr/bin/env bash

inputroot=~/.claws-mail/imapcache

output=~/claws.maildir

find "$inputroot/" -mindepth 2 -type d | while read -r dir; do
	rel=${dir#$inputroot}; rel=/${rel#/}; rel=${rel//./_}; rel=${rel//'/'/.}
	out="$output/$rel"
	find "$dir" -maxdepth 1 -type f -not -name '.*' | while read -r file; do
		newname="claws.${file##*/}.$(stat -c %Y "$file"):2,S"
		if [ ! -d "$out/cur" ]; then
			echo "creating: $out"
			mkdir -p "$out/cur" "$out/new" "$out/tmp"
		fi
		install -Dm0600 "$file" "$out/cur/$newname"
	done
done
