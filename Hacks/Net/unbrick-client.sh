# for loading binary files into a server, when the only program that works is bash.

h=equal.cluenet.org/1111

while read -r f && echo -n "$f" && [[ $f != end. ]]; do
	while read -r n s && echo -n " $n" && ((n && n == ${#s})); do
		eval "printf -- $s" >&3;
	done 3>"./$f";
	echo;
done <"/dev/tcp/$h"; echo
