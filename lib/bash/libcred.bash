# vim: ft=sh

. lib.bash || exit

# create a temporary file on RAM

mkcredfile() {
	mktemp --tmpdir=/dev/shm "credentials.$UID.XXXXXXXX"
}

# readcred(object, [printfmt])
# prompt user for username/password

readcred() {
	local OPT OPTARG OPTIND
	local nouser=false
	local fmt='username=%s\npassword=%s\n'
	local prompt=''
	local user=${user:-$LOGNAME}
	local pass=
	while getopts 'f:p:Uu:' OPT; do
		case $OPT in
		f) fmt=$OPTARG;;
		p) prompt=$OPTARG;;
		U) nouser=true;;
		u) user=$OPTARG;;
		*) die_getopts;;
		esac
	done

	if [[ -t 2 ]]; then
		{
		echo "Enter credentials for $prompt:"
		$nouser || {
			read -rp $'username: \001\e[1m\002' \
				-ei "$user" user
			printf '\e[m'
		}
		read -rp 'password: ' -es pass
		echo ""
		} </dev/tty >/dev/tty
		printf "$fmt" "$user" "$pass"
		return 0
	elif [[ $DISPLAY ]]; then
		zenity --forms \
		--title "Enter credentials" \
		--text "Enter credentials for $prompt:" \
		--add-entry "Username:" \
		--add-password "Password:" \
		--separator $'\n' | {
			read -r user &&
			read -r pass &&
			printf "$fmt" "$user" "$pass"
		}
	else
		echo >&2 "No credentials for $obj found."
		return 1
	fi
}

# getcred_var(host, [service], object, $uservar, $passvar)
# obtain credentials for service@host and put into given variables

getcred_var() {
	local OPT OPTARG
	local nouser=''
	while getopts 'U' OPT; do
		case $OPT in
		U) nouser="-U";;
		*) die_getopts;;
		esac
	done

	local host=$1 service=$2 obj=$3 uvar=${4:-user} pvar=${5:-pass}
	local fmt='%u%n%p' data= udata= pdata=
	local prompt="$obj on $host"
	debug "got host '$host' svc '$service' user $uvar='${!uvar}'"

	if [[ ${!uvar} == @* ]] &&
	   debug "trying netrc for domain '${!uvar#@}' svc '$service'" &&
	   data=$(getnetrc_fqdn "${!uvar#@}" "$service" "" '%u%n%p'); then
		{ read -r udata; read -r pdata; } <<< "$data"
		declare -g "$uvar=$udata" "$pvar=$pdata"
	elif debug "trying netrc for host '$host' svc '$service'" &&
	     data=$(getnetrc_fqdn "$host" "$service" "${!uvar}" '%u%n%p'); then
		{ read -r udata; read -r pdata; } <<< "$data"
		declare -g "$uvar=$udata" "$pvar=$pdata"
	elif data=$(readcred $nouser -p "$prompt" -f '%s\n%s\n'); then
		{ read -r udata; read -r pdata; } <<< "$data"
		declare -g "$uvar=$udata" "$pvar=$pdata"
	else
		return 1
	fi
}

# getcred_samba(host, [service], objectname)
# obtain credentials for service@host, output in smbclient format

getcred_samba() {
	local host=$1 service=$2 obj=$3
	local fmt='username=%u%npassword=%p'
	local prompt="$obj on $host"
	getnetrc_fqdn "$host" "$service" "$fmt" ||
	readcred "$prompt"
}

# getnetrc_fqdn(host, [service], format)
# call getnetrc for [service@]host and [service@]fqdn until success

getnetrc_fqdn() {
	local host=$1 service=$2 user=$3 fmt=$4
	if [[ "$host" == *.* ]]; then
		# TODO: this is a hack and probably makes it
		# not do what I originally wanted
		local fqdn=$host
	else
		local fqdn=$(fqdn "$host")
	fi
	if [[ "$host" == "$fqdn" ]]; then
		debug "searching .netrc for '$service@$host'"
	else
		debug "searching .netrc for '$service@$host' & '$service@$fqdn'"
	fi
	if [[ "$user" ]]; then
		getnetrc -df "$fmt" "$service@$host" "$user" && return
		if [[ "$host" != "$fqdn" ]]; then
			getnetrc -df "$fmt" "$service@$fqdn" "$user" && return
		fi
		getnetrc -df "$fmt" "$service@*.${fqdn#*.}" "$user" && return
	else
		getnetrc -df "$fmt" "$service@$host" && return
		if [[ "$host" != "$fqdn" ]]; then
		       getnetrc -df "$fmt" "$service@$fqdn" && return
		fi
		getnetrc -df "$fmt" "$service@*.${fqdn#*.}" && return
	fi
}
