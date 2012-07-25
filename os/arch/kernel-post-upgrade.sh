#!/bin/sh -eu

efi_install_kernel() {
	local KERNEL=$1

	local KERNEL_VERSION=$(pacman -Q "$KERNEL")
	local KERNEL_VERSION=${KERNEL_VERSION#$KERNEL }

	echo "Found $PRETTY_NAME ($KERNEL $KERNEL_VERSION)"

	echo "Copying kernel to EFI system partition..."
	mkdir -p "$EFI/EFI/$ID"
	cp -f "/boot/vmlinuz-$KERNEL"		"$EFI/EFI/$ID/vmlinuz-$KERNEL.efi"
	cp -f "/boot/initramfs-$KERNEL.img"	"$EFI/EFI/$ID/initramfs-$KERNEL.img"

	if [[ $KERNEL == linux ]]; then
		file=$ID
	else
		file=$ID-${KERNEL#linux-}
	fi

	config=(
		"title"		"$PRETTY_NAME"
		"title-version"	"$KERNEL_VERSION"
		"title-machine"	"${MACHINE_ID:0:8}"
		"linux"		"/EFI/$ID/vmlinuz-$KERNEL.efi"
		"initrd"	"/EFI/$ID/initramfs-$KERNEL.img"
		"options"	"$BOOT_OPTIONS"
	)
	echo "Generating bootloader config ($file.conf)..."
	printf '%s\t%s\n' "${config[@]}" > "$EFI/loader/entries/$file.conf"
}

efi_remove_kernel() {
	local KERNEL=$1

	echo "Uninstalling $PRETTY_NAME ($KERNEL)"

	echo "Removing kernel from EFI system partition..."
	rm -f "$EFI/EFI/$ID/vmlinuz-$KERNEL.efi"
	rm -f "$EFI/EFI/$ID/initramfs-$KERNEL.img"

	if [[ $KERNEL == linux ]]; then
		file=$ID
	else
		file=$ID-${KERNEL#linux-}
	fi

	echo "Removing bootloader config..."
	rm -f "$EFI/loader/entries/$file.conf"
}

if [[ -d /boot/loader ]]; then
	EFI=/boot
elif [[ -d /boot/efi/loader ]]; then
	EFI=/boot/efi
else
	echo "error: EFI partition not found; please mkdir <efi>/loader" >&2
	exit 1
fi

# read machine information

KERNEL='linux' # the package name

. /etc/os-release

read -r MACHINE_ID < /etc/machine-id

read -r BOOT_OPTIONS < /etc/kernel/cmdline

# find the kernel

if [[ -e "/boot/vmlinuz-$KERNEL" ]]; then
	efi_install_kernel "$KERNEL"
else
	efi_remove_kernel "$KERNEL"
fi
