if have setfattr; then
	ks:getattr() {
		local file=$1 name=$2
		getfattr "$file" --name="user.$name" --only-values 2>/dev/null
	}

	ks:setattr() {
		local file=$1 name=$2 value=$3
		setfattr "$file" --name="user.$name" --value="$value"
	}

	ks:delattr() {
		local file=$1 name=$2
		setfattr "$file" --remove="user.$name" 2>/dev/null
	}
elif have attr; then
	ks:getattr() {
		local file=$1 name=$2
		attr -q -g "$name" "$file" 2>/dev/null
	}

	ks:setattr() {
		local file=$1 name=$2 value=$3
		attr -q -s "$name" -V "$value" "$file"
	}

	ks:delattr() {
		local file=$1 name=$2
		attr -q -r "$name" "$file" 2>/dev/null
	}
fi

ks:sshrun() {
	local OPT OPTARG OPTIND
	local host= argv=() optv=()
	local -i i
	while getopts "t" OPT "$@"; do
		case $OPT in
		t) optv+=("-t");;
		esac
	done
	shift $((OPTIND-1))
	host=$1 argv=("${@:2}")
	for (( i = 0; i < ${#argv[@]}; i++ )); do
		printf -v argv[i] '%q' "${argv[i]}"
	done
	debug "running \"${argv[*]}\" on $host"
	ssh "$host" \
		-o ControlMaster=auto \
		-o ControlPersist=5m \
		-o ControlPath="~/.ssh/S.%r@%h:%p" \
		"${optv[@]}" \
		"${argv[*]}"
}

ks:older_than() {
	local file=$1 date=$2 filets datets
	filets=$(stat -c %y "$file")
	datets=$(date +%s -d "$date ago")
	(( filets < datets ))
}

ks:larger_than() {
	local file=$1 size=$2 filesz
	filesz=$(stat -c %s "$file")
	(( filesz > size ))
}

# ks:next_file_slot($base) -> $slot
# $base: printf template with one %d or %s
# Finds the first nonexistent file named after $base.
# Not atomic/racefree.

ks:next_file_slot() {
	local base=$1 i=0 step=10 file=
	while true; do
		(( i += step ))
		printf -v file "$base" "$i"
		if [[ ! -e $file ]]; then
			if (( step == 1 )); then
				echo "$i"
				return
			fi
			(( i -= step ))
			(( step = 1 ))
		fi
	done
}
