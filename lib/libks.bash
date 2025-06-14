path_cache="$XDG_CACHE_HOME/nullroute.eu.org"
path_config="$XDG_CONFIG_HOME/nullroute.eu.org"
path_data="$XDG_DATA_HOME/nullroute.eu.org"

ks:getattr() {
	local file=$1 name=$2
	if have getfattr; then
		getfattr "$file" --name="user.$name" --only-values 2>/dev/null
	else
		attr -q -g "$name" "$file" 2>/dev/null
	fi
}

ks:setattr() {
	local file=$1 name=$2 value=$3
	if have setfattr; then
		debug "setting 'user.$name' to '$value' via setfattr"
		setfattr "$file" --name="user.$name" --value="$value"
	elif have attr; then
		debug "setting 'user.$name' to '$value' via attr"
		attr -q -s "$name" -V "$value" "$file"
	else
		debug "cannot set 'user.$name', no interface"
	fi
}

ks:delattr() {
	local file=$1 name=$2
	if have setfattr; then
		setfattr "$file" --remove="user.$name" 2>/dev/null
	else
		attr -q -r "$name" "$file" 2>/dev/null
	fi
}

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

# ks:find_file(&$var, @paths) -> nil
#   $var: variable to set
#   @paths: list of paths to check for existence
# Finds the first existing file in list; if none exist, returns the last path
# and ensures its parent directory exists.

ks:find_file() {
	local var=${1%=} _file
	for _file in "${@:2}"; do
		case $_file in
			cache:/*)    _file=$XDG_CACHE_HOME/${_file#*/};;
			cache:*)     _file=$path_cache/${_file#*:};;
			config:/*)   _file=$XDG_CONFIG_HOME/${_file#*/};;
			config:*)    _file=$path_config/${_file#*:};;
			data:/*)     _file=$XDG_DATA_HOME/${_file#*/};;
			data:*)      _file=$path_data/${_file#*:};;
		esac
		if [[ -e "$_file" ]]; then
			debug "found $var = '$_file'"
			eval "$var=\$_file"
			return 0
		fi
	done
	debug "fallback $var = '$_file'"
	if [[ ! -d "${_file%/*}" ]]; then
		mkdir -p "${_file%/*}"
	fi
	eval "$var=\$_file"
	return 1
}

# ks:next_file_slot($base) -> $slot
#   $base: printf template with one %d or %s
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
