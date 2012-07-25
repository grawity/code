#!/bin/sh -eu

check_kernel() {
	local kernel=$1
	local suffix=
	local config=$ID

	if [[ $kernel != 'linux' ]]; then
		suffix="-${kernel#'linux-'}"
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
		echo "Error: package '$kernel' does not exist"
		return 1
	fi

	echo "Found $PRETTY_NAME ($kernel $version)"

	echo "+ copying kernel to EFI system partition"
	mkdir -p "$EFI/EFI/$ID"
	cp -f "/boot/vmlinuz-$kernel"		"$EFI/EFI/$ID/vmlinuz-$kernel"
	cp -f "/boot/initramfs-$kernel.img"	"$EFI/EFI/$ID/initramfs-$kernel.img"

	parameters=(
		"title"		"$PRETTY_NAME"
		"title-version"	"$version"
		"title-machine"	"${MACHINE_ID:0:8}"
		"linux"		"/EFI/$ID/vmlinuz-$kernel.efi"
		"initrd"	"/EFI/$ID/initramfs-$kernel.img"
		"options"	"$BOOT_OPTIONS"
	)
	echo "+ generating bootloader config"
	printf '%s\t%s\n' "${parameters[@]}" > "$EFI/loader/entries/$config.conf"
}

remove_kernel() {
	echo "Uninstalling $PRETTY_NAME ($kernel)"

	echo "+ removing kernel from EFI system partition"
	rm -f "$EFI/EFI/$ID/vmlinuz-$kernel.efi"
	rm -f "$EFI/EFI/$ID/initramfs-$kernel.img"

	echo "+ removing bootloader config"
	rm -f "$EFI/loader/entries/$config.conf"
}

if [[ -d /boot/loader ]]; then
	EFI=/boot
elif [[ -d /boot/efi/loader ]]; then
	EFI=/boot/efi
else
	echo "error: EFI partition not found; please mkdir <efi>/loader" >&2
	exit 1
fi

. /etc/os-release

read -r MACHINE_ID < /etc/machine-id

read -r BOOT_OPTIONS < /etc/kernel/cmdline

KERNEL=${1:-'linux'}

check_kernel "$KERNEL"
