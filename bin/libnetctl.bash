#!bash
. lib.bash || exit

: ${VIRTUALBOX_LIBEXEC:='/usr/lib/virtualbox'}

# check if device $1 exists
dev_exists() {
	local dev=$1
	[[ -e "/sys/class/net/$dev" ]]
}

dev_is_eth() {
	local dev=$1
	local devtype=$(<"/sys/class/net/$dev/type")
	(( devtype == 1 ))
}

dev_is_p2p() {
	local dev=$1
	local devtype=$(<"/sys/class/net/$dev/type")
	(( devtype == 65534 ))
}

dev_is_bridge() {
	local dev=$1
	[[ -e "/sys/class/net/$dev/bridge" ]]
}

dev_is_tap() {
	local dev=$1
	[[ -e "/sys/class/net/$dev/tun_flags" ]] &&
		dev_is_eth "$dev"
}

dev_is_tun() {
	local dev=$1
	[[ -e "/sys/class/net/$dev/tun_flags" ]] &&
		dev_is_p2p "$dev"
}

dev_is_wireless() {
	local dev=$1
	[[ -e "/sys/class/net/$dev/wireless" ]]
}

# create device $1 if possible
dev_create() {
	local dev=$1
	local parent=

	log "creating '$dev'"
	if dev_exists "$dev"; then
		warn "cannot create '$dev' - interface already exists"
		return
	fi

	case $dev in
	br*)
		debug "creating '$dev' as bridge"
		brctl addbr "$dev"
		;;
	mon*)
		if [[ $dev == */* ]]; then
			parent=${dev#*/}
			dev=${dev%%/*}
		else
			parent=${dev/#mon/phy}
		fi
		debug "creating '$dev' as wireless/monitor on '$parent'"
		iw phy "$parent" interface add "$dev" type monitor
		;;
	tap*)
		debug "creating '$dev' as tap"
		ip tuntap add dev "$dev" mode tap
		;;
	tun*)
		debug "creating '$dev' as tun"
		ip tuntap add dev "$dev" mode tun
		;;
	vboxnet*)
		debug "creating '$dev' as vboxnet"
		modprobe vboxnetadp
		"$VIRTUALBOX_LIBEXEC/VBoxNetAdpCtl" "$dev" add
		;;
	wds*)
		if [[ $dev == */* ]]; then
			parent=${dev#*/}
			dev=${dev%%/*}
		else
			parent=${dev/#wds/phy}
		fi
		debug "creating '$dev' as wireless/wds on '$parent'"
		iw phy "$parent" interface add "$dev" type wds
		;;
	wlan*)
		if [[ $dev == */* ]]; then
			parent=${dev#*/}
			dev=${dev%%/*}
		else
			parent=${dev/#wlan/phy}
		fi
		debug "creating '$dev' as wireless on '$parent'"
		iw phy "$parent" interface add "$dev" type managed
		;;
	*)
		err "cannot create '$dev' - static interface or unknown type"
		return
		;;
	esac || err "cannot create '$dev' - generic failure"
}

# destroy device $1
dev_destroy() {
	local dev=$1

	log "destroying '$dev'"
	if ! dev_exists "$dev"; then
		warn "cannot destroy '$dev' - interface does not exist"
		return
	fi
	dev_bring_down "$dev"
	if dev_is_bridge "$dev"; then
		debug "destroying '$dev' as bridge"
		ip link set dev "$dev" down
		brctl delbr "$dev"
	elif dev_is_tap "$dev"; then
		debug "destroying '$dev' as tap"
		ip tuntap del dev "$dev" mode tap
	elif dev_is_tun "$dev"; then
		debug "destroying '$dev' as tun"
		ip tuntap del dev "$dev" mode tun
	elif dev_is_wireless "$dev"; then
		debug "destroying '$dev' as wireless"
		iw dev "$dev" del
	elif [[ $dev == vboxnet* ]]; then
		debug "destroying '$dev' as vboxnet"
		"$VIRTUALBOX_LIBEXEC/VBoxNetAdpCtl" "$dev" remove
	else
		err "cannot destroy '$dev' - static interface or unknown type"
		return
	fi || err "cannot destroy '$dev' - generic failure"
}

dev_is_lower_up() {
	local dev=$1
	dev_exists "$dev" || return
	local state=$(<"/sys/class/net/$dev/operstate")
	[[ $state == "up" ]]
}

dev_bring_up() {
	local dev=$1
	dev_exists "$dev" || dev_create "$dev"
	debug "bringing '$dev' up"
	ip link set dev "$dev" up
}

dev_bring_down() {
	local dev=$1
	debug "bringing '$dev' down"
	ip link set dev "$dev" down
}

dev_rename() {
	local dev=$1 new=$2
	debug "renaming '$dev' to '$new'"
	ip link set dev "$dev" name "$new"
}

br_has_slave() {
	local master=$1 slave=$2
	[[ -e "/sys/class/net/$master/brif/$slave" ]]
}

br_add_slave() {
	local master=$1 slave=$2

	debug "enslaving '$slave' to '$master'"
	if br_has_slave "$master" "$slave"; then
		debug "'$slave' already belongs to bridge '$master', ignoring"
		return 0
	fi
	brctl addif "$master" "$slave"
}

br_rm_slave() {
	local master=$1 slave=$2

	debug "unslaving '$slave' from '$master'"
	if ! br_has_slave "$master" "$slave"; then
		debug "'$slave' doesn't belong to bridge '$master', ignoring"
		return 0
	fi
	brctl delif "$master" "$slave"
}
