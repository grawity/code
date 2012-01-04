#!bash

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

	log "creating '$dev'"
	if dev_exists "$dev"; then
		warn "cannot create '$dev' - already exists"
		return
	fi
	case $dev in
	br*)
		brctl addbr "$dev"
		;;
	tap*)
		ip tuntap add dev "$dev" mode tap
		;;
	tun*)
		ip tuntap add dev "$dev" mode tun
		;;
	vboxnet*)
		modprobe vboxnetadp
		"$VIRTUALBOX_LIBEXEC/VBoxNetAdpCtl" "$dev" add
		;;
	*)
		err "cannot create '$dev' - static device or unknown type"
		return
		;;
	esac || err "cannot create '$dev' - generic failure"
}

# destroy device $1
dev_destroy() {
	local dev=$1

	log "destroying '$dev'"
	if ! dev_exists "$dev"; then
		warn "cannot destroy '$dev' - does not exist"
		return
	fi
	if dev_is_bridge "$dev"; then
		ip link set dev "$dev" down
		brctl delbr "$dev"
	elif dev_is_tap "$dev"; then
		ip tuntap del dev "$dev" mode tap
	elif dev_is_tun "$dev"; then
		ip tuntap del dev "$dev" mode tun
	elif dev_is_wireless "$dev"; then
		iw dev "$dev" del
	elif [[ $dev == vboxnet* ]]; then
		"$VIRTUALBOX_LIBEXEC/VBoxNetAdpCtl" "$dev" remove
	else
		err "cannot destroy '$dev' - static device or unknown type"
		return
	fi || err "cannot destroy '$dev' - generic failure"
}

br_has_slave() {
	local master=$1 slave=$2

	[[ -e "/sys/class/net/$master/brif/$slave" ]]
}

br_add_slave() {
	local master=$1 slave=$2

	if br_has_slave "$master" "$slave"; then
		log "'$slave' already belongs to bridge '$master'"
		return 0
	fi
	brctl addif "$master" "$slave"
}

br_del_slave() {
	local master=$1 slave=$2

	if ! br_has_slave "$master" "$slave"; then
		log "device '$slave' doesn't belong to bridge '$master'"
		return 0
	fi
	brctl delif "$master" "$slave"
}
