#!/bin/bash

PATH=/usr/bin:$PATH
dirs='/bin /sbin /usr/sbin'
dbdir=/var/lib/pacman/local

if [ -e $dbdir.bak ]; then
	echo "error: pacman DB backup already exists" >&2
	exit 1
fi

echo ".checking for possible conflicts"
err=0
for dir in $dirs; do
	if [ -l $dir ]; then
		echo "error: $dir is already a symlink" >&2
		(( ++err ))
		continue
	fi
	for file in $dir/*; do
		base=${file##*/}
		if [ -e "/usr/bin/$base" ]; then
			echo "error: file $file conflicts with /usr/bin/$base" >&2
			(( ++err ))
		fi
	done
done
(( err == 0 )) || exit

echo ".moving files to /usr/bin"
for dir in $dirs; do
	echo ".moving $dir contents to /usr/bin"
	for file in $dir/*; do
		mv -i "$file" /usr/bin/ || exit
	done
	echo ".removing $dir"
	rmdir -v "$dir" || exit
	echo ".symlinking $dir"
	case $dir in
	/usr/*) ln -vs "bin" "$dir";;
	*)      ln -vs "usr/bin" "$dir";;
	esac || exit
done

echo ".making a backup of pacman DB"
cp -a $dbdir $dbdir.bak

echo ".editing pacman DB"
for flist in $dbdir/*/files; do
	pkg=${flist%/files}
	pkg=${pkg##*/}
	pkg=${pkg%-*-*}
	sed -r -i 's,^(bin|sbin|usr/sbin)(/.+|)$,usr/bin/\2,' "$flist"
	echo -n "$pkg "
done
echo "done."
