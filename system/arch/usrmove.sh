#!/bin/bash

err() { echo "error: $*" >&2; (( ++err )); }

PATH=/usr/bin:$PATH
dbdir=/var/lib/pacman/local

if [ -e $dbdir.bak ]; then
	err "pacman DB backup already exists"
	exit 1
fi

echo ".checking for possible conflicts"
err=0
for dir in /bin /sbin /usr/sbin; do
	if [[ -L "$dir" ]]; then
		err "'$dir' is already a symlink"
		continue
	elif [[ ! -d "$dir" ]]; then
		err "'$dir' is not a directory"
		continue
	fi
	for file in "$dir"/*; do
		base=${file##*/}
		other=/usr/bin/$base
		if [[ -e "$other" ]]; then
			err "file '$file' conflicts with '$other'"
			if [[ "$file" -ef "$other" ]] && [[ -L "$file" ]]; then
				err "  - file '$file' is a symlink to '$other'"
				err "  - suggestion: delete '$file'"
			elif [[ "$file" -ef "$other" ]] && [[ -L "$other" ]]; then
				err "  - file '$other' is a symlink to '$file'"
				err "  - suggestion: delete '$other'"
			elif cmp -s "$file" "$other"; then
				err "  - file '$file' is identical to '$other'"
				err "  - suggestion: delete '$file'"
			else
				err "  - files differ, manual resolution needed"
			fi
		fi
	done
done
(( err == 0 )) || exit

echo ".moving files to /usr/bin"
for dir in /bin /sbin /usr/sbin; do
	echo ".moving $dir contents to /usr/bin"
	for file in "$dir"/*; do
		mv -i "$file" /usr/bin/ || {
			err "could not move '$file' to /usr/bin, stopping"
			exit
		}
	done

	echo ".removing $dir"
	rmdir -v "$dir" || {
		err "could not remove empty directory '$dir', stopping"
		exit
	}

	echo ".symlinking $dir"
	case $dir in
		/usr/*) target="bin";;
		/*) target="usr/bin";;
	esac

	ln -vs "$target" "$dir" || {
		err "could not symlink '$dir' to '$target', stopping"
		exit
	}
done

echo ".making a backup of pacman DB"
cp -a $dbdir $dbdir.bak

echo ".editing pacman DB"
for flist in $dbdir/*/files; do
	pkg=${flist%/files}
	pkg=${pkg##*/}
	pkg=${pkg%-*-*}
	sed -r -i 's,^(bin|sbin|usr/sbin)(/.+|)$,usr/bin\2,' "$flist"
	echo -n "$pkg "
done
echo "done."
