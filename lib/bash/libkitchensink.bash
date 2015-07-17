ks:getattr() {
	local file=$1 name=$2
	getfattr "$file" --name="user.$name" --only-values 2>/dev/null
}

ks:setattr() {
	local file=$1 name=$2 value=$3
	setfattr "$file" --name="user.$name" --value="$value"
}
