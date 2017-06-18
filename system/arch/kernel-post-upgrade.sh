#!/usr/bin/bash -eu

err() { echo "error: $*" >&2; return 1; }

die() { err "$*"; exit 1; }

try_esp() {
	mountpoint -q "$1" && [[ -d "$1/EFI" ]] && [[ -d "$1/loader" ]]
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
		err "package '$kernel' does not exist"
		return
	fi

	echo "Installing package: $kernel $version as \"$PRETTY_NAME\""

	if [[ $ESP != /boot ]]; then
		echo "+ copying kernel to EFI system partition"
		mkdir -p "$ESP/EFI/$ID"
		cp -f "/boot/vmlinuz-$kernel"		"$ESP/EFI/$ID/vmlinuz-$kernel.efi"
		cp -f "/boot/intel-ucode.img"		"$ESP/EFI/$ID/intel-ucode.img"
		cp -f "/boot/initramfs-$kernel.img"	"$ESP/EFI/$ID/initramfs-$kernel.img"
	fi

	echo "+ generating bootloader config"
	if [[ $ESP == /boot ]]; then
		parameters=(
			"title"		"$PRETTY_NAME"
			"version"	"$version"
			"machine-id"	"$MACHINE_ID"
			"linux"		"\\vmlinuz-$kernel"
			"initrd"	"\\intel-ucode.img"
			"initrd"	"\\initramfs-$kernel.img"
			"options"	"$BOOT_OPTIONS"
		)
	else
		parameters=(
			"title"		"$PRETTY_NAME"
			"version"	"$version"
			"machine-id"	"$MACHINE_ID"
			"linux"		"\\EFI\\$ID\\vmlinuz-$kernel.efi"
			"initrd"	"\\EFI\\$ID\\intel-ucode.img"
			"initrd"	"\\EFI\\$ID\\initramfs-$kernel.img"
			"options"	"$BOOT_OPTIONS"
		)
	fi
	mkdir -p "$ESP/loader/entries"
	printf '%s\t%s\n' "${parameters[@]}" > "$ESP/loader/entries/$config.conf"
}

remove_kernel() {
	echo "Uninstalling package: $kernel"

	echo "+ removing kernel from EFI system partition"
	rm -f "$ESP/EFI/$ID/vmlinuz-$kernel.efi"
	rm -f "$ESP/EFI/$ID/initramfs-$kernel.img"

	echo "+ removing bootloader config"
	rm -f "$ESP/loader/entries/$config.conf"
}

declare ESP= os_release=
unset ID NAME PRETTY_NAME MACHINE_ID BOOT_OPTIONS

for f in /efi /boot/efi /boot; do
	[[ $ESP ]] || { try_esp "$f" && ESP=$f; }
done

[[ $ESP ]] ||
	die "EFI system partition not found; please \`mkdir <efisys>/loader\`"

echo "Found EFI system partition at $ESP"

for f in /etc/os-release /usr/lib/os-release; do
	[[ $os_release ]] || { [[ -e $f ]] && os_release=$f; }
done

[[ $os_release ]] ||
	die "/usr/lib/os-release not found or invalid; see os-release(5)"

. "$os_release" ||
	die "$os_release not found or invalid; see os-release(5)"

[[ ${PRETTY_NAME:=$NAME} ]] ||
	die "$os_release is missing both PRETTY_NAME and NAME; see os-release(5)"

[[ $ID ]] ||
	die "$os_release is missing ID; see os-release(5)"

read -r MACHINE_ID < /etc/machine-id ||
	die "/etc/machine-id not found or empty; see machine-id(5)"

[[ -s /etc/kernel/cmdline ]] ||
	die "/etc/kernel/cmdline not found or empty; please configure it"

BOOT_OPTIONS=(`grep -v "^#" /etc/kernel/cmdline`)
BOOT_OPTIONS=${BOOT_OPTIONS[*]}

check_kernel "${1:-linux}"
