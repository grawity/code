#!/bin/bash -eu

die() {
	echo "$*" >&2
	exit 1
}

same_fs() {
	test "$(stat -c %d "$1")" = "$(stat -c %d "$2")"
}

check_kernel() {
	local kernel=$1
	local suffix=
	local config=$ID

	if [[ $kernel != 'linux' ]]; then
		suffix="-${kernel#linux-}"
		config=$config$suffix
	fi

	if [[ -e "/boot/vmlinuz-$kernel" ]]; then
		install_kernel
	else
		remove_kernel
	fi
}

install_kernel() {
	local version=

	if version=$(pacman -Q "$kernel" 2>/dev/null); then
		version=${version#"$kernel "}${suffix}
	else
		echo "error: package '$kernel' does not exist"
		return 1
	fi

	echo "Found $PRETTY_NAME ($kernel $version)"

	echo "+ copying kernel to EFI system partition"
	mkdir -p "$ESP/EFI/$ID"
	cp -f "/boot/vmlinuz-$kernel"		"$ESP/EFI/$ID/vmlinuz-$kernel.efi"
	cp -f "/boot/initramfs-$kernel.img"	"$ESP/EFI/$ID/initramfs-$kernel.img"

	parameters=(
		"title"		"$PRETTY_NAME"
		"title-version"	"$version"
		"title-machine"	"${MACHINE_ID:0:8}"
		"linux"		"\\EFI\\$ID\\vmlinuz-$kernel.efi"
		"initrd"	"\\EFI\\$ID\\initramfs-$kernel.img"
		"options"	"$BOOT_OPTIONS"
	)
	echo "+ generating bootloader config"
	mkdir -p "$ESP/loader/entries"
	printf '%s\t%s\n' "${parameters[@]}" > "$ESP/loader/entries/$config.conf"
}

remove_kernel() {
	echo "Uninstalling $PRETTY_NAME ($kernel)"

	echo "+ removing kernel from EFI system partition"
	rm -f "$ESP/EFI/$ID/vmlinuz-$kernel.efi"
	rm -f "$ESP/EFI/$ID/initramfs-$kernel.img"

	echo "+ removing bootloader config"
	rm -f "$ESP/loader/entries/$config.conf"
}

unset ID NAME PRETTY_NAME MACHINE_ID BOOT_OPTIONS

if [[ -d /boot/efi/EFI && -d /boot/efi/loader ]]; then
	ESP=/boot/efi
elif [[ -d /boot/EFI && -d /boot/loader ]]; then
	ESP=/boot
else
	die "error: EFI system partition not found; please \`mkdir <efisys>/loader\`"
fi

echo "Found EFI system partition at $ESP"

. /etc/os-release ||
	die "error: /etc/os-release not found or invalid; see os-release(5)"

[[ ${PRETTY_NAME:=$NAME} ]] ||
	die "error: /etc/os-release is missing both PRETTY_NAME and NAME; see os-release(5)"

[[ $ID ]] ||
	die "error: /etc/os-release is missing ID; see os-release(5)"

read -r MACHINE_ID < /etc/machine-id ||
	die "error: /etc/machine-id not found or empty; see machine-id(5)"

[[ -s /etc/kernel/cmdline ]] ||
	die "error: /etc/kernel/cmdline not found or empty; please configure it"

BOOT_OPTIONS=(`grep -v "^#" /etc/kernel/cmdline`)
BOOT_OPTIONS=${BOOT_OPTIONS[*]}

check_kernel "${1:-linux}"
