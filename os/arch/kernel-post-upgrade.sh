#!/bin/sh -eu

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

KERNEL_VERSION=$(pacman -Q "$KERNEL")
KERNEL_VERSION=${KERNEL_VERSION#$KERNEL }

echo "Found $PRETTY_NAME ($KERNEL $KERNEL_VERSION)"

# copy kernel to EFI partition

echo "Copying kernel to EFI system partition..."

mkdir -p "$EFI/EFI/$ID"
cp -f "/boot/vmlinuz-$KERNEL"		"$EFI/EFI/$ID/vmlinuz-$KERNEL.efi"
cp -f "/boot/initramfs-$KERNEL.img"	"$EFI/EFI/$ID/initramfs-$KERNEL.img"

# update Gummiboot config

if [[ $KERNEL == linux ]]; then
	file=$ID
else
	file=$ID-${KERNEL#linux-}
fi

echo "Generating bootloader config ($file.conf)..."

config=(
	"title"		"$PRETTY_NAME"
	"title-version"	"$KERNEL_VERSION"
	"title-machine"	"${MACHINE_ID:0:8}"
	"linux"		"/EFI/$ID/vmlinuz-$KERNEL.efi"
	"initrd"	"/EFI/$ID/initramfs-$KERNEL.img"
	"options"	"$BOOT_OPTIONS"
)

printf '%s\t%s\n' "${config[@]}" > "$EFI/loader/entries/$file.conf"
