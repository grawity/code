#!/bin/sh -eu

same_fs() {
	test "$(stat -c %d "$1")" = "$(stat -c %d "$2")"
}

list_configs() {
	find "$ESP/loader/entries" \
		\( -name "$ID.conf" -o -name "$ID-*.conf" \)\
		-printf '%f\n' | sed "s/^$ID/linux/; s/\.conf\$//"
}

check_all() {
	list-configs | while read kernel; do
		check_kernel "$kernel"
	done
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
		echo "Error: package '$kernel' does not exist"
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

if [[ -d /boot/EFI && -d /boot/loader ]]; then
	ESP=/boot
elif [[ -d /boot/efi/EFI && -d /boot/efi/loader ]]; then
	ESP=/boot/efi
else
	echo "error: EFI system partition not found; please mkdir <efi>/loader" >&2
	exit 1
fi

echo "Found EFI system partition at $ESP"

. /etc/os-release
read -r MACHINE_ID < /etc/machine-id
read -r BOOT_OPTIONS < /etc/kernel/cmdline

check_kernel "${1:-linux}"
