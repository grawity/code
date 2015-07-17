ks:getattr() {
	local file=$1 name=$2
	getfattr "$file" --name="user.$name" --only-values 2>/dev/null
}

ks:setattr() {
	local file=$1 name=$2 value=$3
	setfattr "$file" --name="user.$name" --value="$value"
}

ks:sshrun() {
	local host=$1 argv=("${@:2}")
	local -i i
	for (( i = 0; i < ${#argv[@]}; i++ )); do
		printf -v argv[i] '%q' "${argv[i]}"
	done
	debug "running \"${argv[*]}\" on $host"
	ssh "$host" \
		-o ControlMaster=auto \
		-o ControlPersist=5m \
		-o ControlPath="~/.ssh/S.%r@%h:%p" \
		"${argv[*]}"
}
